// lib/features/weather/presentation/locations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/domain/units.dart';
import 'package:glass/features/weather/domain/weather_code.dart';
import 'package:glass/features/weather/presentation/add_location_sheet.dart';

/// The places overview — every saved city with its current conditions, so the
/// list itself shows the weather and tapping a city jumps Home to it (the
/// research's "directly-accessible list" — clearer than a hidden swipe).
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, SavedLocation loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${loc.label}?'),
        content: const Text('This forgets the place and its cached forecast.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(locationsRepositoryProvider).remove(loc.id);
    }
  }

  void _open(BuildContext context, WidgetRef ref, SavedLocation loc) {
    ref.read(selectedCityIdProvider.notifier).state = loc.id;
    context.pop(); // back to Home, which animates to this city
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedLocationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Places'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add a place',
            onPressed: () => showAddLocationSheet(context),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (locations) {
          if (locations.isEmpty) {
            return Center(
              child: TextButton.icon(
                onPressed: () => showAddLocationSheet(context),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Add your first place'),
              ),
            );
          }
          return ReorderableListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            onReorder: (oldI, newI) {
              final ids = locations.map((l) => l.id).toList();
              if (newI > oldI) newI -= 1;
              final moved = ids.removeAt(oldI);
              ids.insert(newI, moved);
              ref.read(locationsRepositoryProvider).reorder(ids);
            },
            children: [
              for (final loc in locations)
                ListTile(
                  key: ValueKey(loc.id),
                  onTap: () => _open(context, ref, loc),
                  leading: Icon(loc.isCurrent
                      ? LucideIcons.navigation
                      : LucideIcons.mapPin),
                  title: Text(loc.label),
                  subtitle: loc.sublabel == null ? null : Text(loc.sublabel!),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CityConditions(locationId: loc.id),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        tooltip: 'Remove',
                        onPressed: () => _confirmRemove(context, ref, loc),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The current temperature + condition glyph for one saved place (cache-aware,
/// so the overview is cheap). Quietly shows nothing until the forecast loads.
class _CityConditions extends ConsumerWidget {
  const _CityConditions({required this.locationId});
  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final async = ref.watch(forecastProvider(locationId));
    final cs = Theme.of(context).colorScheme;
    return async.when(
      loading: () => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => Text('—', style: TextStyle(color: cs.onSurfaceVariant)),
      data: (f) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatTemp(f.current.temperatureC, units),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 6),
          Icon(iconFor(f.current.condition, f.current.isDay),
              size: 20, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
