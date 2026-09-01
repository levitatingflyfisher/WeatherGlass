// lib/features/weather/presentation/locations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/domain/units.dart';
import 'package:glass/features/weather/domain/weather_code.dart';
import 'package:glass/features/weather/presentation/add_location_sheet.dart';

/// The places overview — every saved city with its current conditions, so the
/// list itself shows the weather and tapping a city jumps Home to it (the
/// research's "directly-accessible list" — clearer than a hidden swipe).
class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  // One pending Undo at a time. It never times out: it ends on Undo, on
  // Dismiss, on the next removal, or when the person leaves this screen
  // (the fleet delete ruling).
  final _undo = OhUndoController();

  @override
  void dispose() {
    _undo.dispose();
    super.dispose();
  }

  /// A tap on the trash button is deliberate, so it does not ask first: the
  /// place goes at once and the bar offers it back.
  Future<void> _remove(SavedLocation loc) async {
    final repo = ref.read(locationsRepositoryProvider);
    final removed = await repo.remove(loc.id);
    if (!mounted) return;
    _undo.show(
      message: 'Removed ${loc.label}',
      onUndo: () => repo.restore(removed,
          precision: ref.read(settingsProvider).precision),
    );
  }

  void _open(SavedLocation loc) {
    ref.read(selectedCityIdProvider.notifier).state = loc.id;
    context.pop(); // back to Home, which animates to this city
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(savedLocationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Places'),
        actions: [
          TextButton.icon(
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add'),
            onPressed: () => showAddLocationSheet(context),
          ),
          OhThemeToggle(
            value: ref.watch(settingsProvider.select((s) => s.theme)),
            onChanged: ref.read(settingsProvider.notifier).setTheme,
          ),
        ],
      ),
      bottomNavigationBar: OhUndoBar(controller: _undo),
      // No gutter: the list tiles carry their own 16 dp padding.
      body: OhPage(
        padding: EdgeInsets.zero,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => OhErrorState.fromError(e,
              stackTrace: st,
              title: 'Couldn’t open your saved places',
              onRetry: () => ref.invalidate(savedLocationsProvider)),
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
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 8),
              onReorder: (oldI, newI) {
                final ids = locations.map((l) => l.id).toList();
                if (newI > oldI) newI -= 1;
                final moved = ids.removeAt(oldI);
                ids.insert(newI, moved);
                ref.read(locationsRepositoryProvider).reorder(ids);
              },
              children: [
                for (final (i, loc) in locations.indexed)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey(loc.id),
                    index: i,
                    child: ListTile(
                      onTap: () => _open(loc),
                      // The drag handle sits at the start of the row, away from
                      // the trash button at the end (a long press anywhere also
                      // drags). The default handle sat right against the trash.
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Tooltip(
                              message: 'Drag to reorder',
                              child: Icon(LucideIcons.gripVertical,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(loc.isCurrent
                              ? LucideIcons.navigation
                              : LucideIcons.mapPin),
                        ],
                      ),
                      title: Text(loc.label),
                      subtitle:
                          loc.sublabel == null ? null : Text(loc.sublabel!),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CityConditions(locationId: loc.id),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            tooltip: 'Remove ${loc.label}',
                            onPressed: () => _remove(loc),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
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
