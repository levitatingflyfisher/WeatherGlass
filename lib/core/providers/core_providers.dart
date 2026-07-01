// lib/core/providers/core_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/data/locations_repository.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/data/weather_repository.dart';
import 'package:glass/features/settings/settings_controller.dart';

part 'core_providers.g.dart';

/// Seeded in main() before the ProviderScope; overridden there.
final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// Set by the Places overview to ask Home to jump to a city (then Home clears
/// it). Lets the list double as a switcher without coupling the two screens.
final selectedCityIdProvider = StateProvider<String?>((ref) => null);

// keepAlive: these own a closeable resource (the DB handle / the HTTP client).
// As autoDispose providers they were torn down — and closed — the instant a
// `ref.read` with no live listener returned, which aborted any in-flight request
// (e.g. the place-search `ref.read(openMeteoProvider)` → "Search failed"). As
// app-singletons they live for the session; onDispose now fires only at teardown.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
OpenMeteo openMeteo(Ref ref) {
  final client = OpenMeteo();
  ref.onDispose(client.close);
  return client;
}

@riverpod
LocationsRepository locationsRepository(Ref ref) =>
    LocationsRepository(ref.watch(appDatabaseProvider));

@riverpod
WeatherRepository weatherRepository(Ref ref) => WeatherRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(openMeteoProvider),
    );

/// All saved places, in display order — the Home page-view and the Places list.
@riverpod
Stream<List<SavedLocation>> savedLocations(Ref ref) =>
    ref.watch(locationsRepositoryProvider).watchAll();

/// The forecast for one saved location (cache-aware). Invalidate to refresh.
@riverpod
Future<Forecast> forecast(Ref ref, String locationId) async {
  // Watch the saved-locations STREAM (not a one-shot byId) so a coordinate
  // change to this place — e.g. re-resolving "My location" into a new rounded
  // cell while Home stays mounted behind the add-sheet — recomputes the forecast
  // instead of leaving the previous location's weather on screen. getForecast is
  // cache-aware, so unchanged places re-resolve from cache (no extra network).
  final locations = await ref.watch(savedLocationsProvider.future);
  // Watch the precision setting so lowering it re-rounds (and refetches) every
  // forecast — the send-boundary rounding below only helps if a precision change
  // actually recomputes this provider.
  final precision = ref.watch(settingsProvider).precision;
  SavedLocation? loc;
  for (final l in locations) {
    if (l.id == locationId) {
      loc = l;
      break;
    }
  }
  if (loc == null) throw WeatherException('That place is no longer saved.');
  return ref
      .watch(weatherRepositoryProvider)
      .getForecast(loc, precision: precision);
}
