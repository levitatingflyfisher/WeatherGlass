// lib/features/weather/presentation/locations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/presentation/add_location_sheet.dart';

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
                  leading: Icon(
                      loc.isCurrent ? LucideIcons.navigation : LucideIcons.mapPin),
                  title: Text(loc.label),
                  subtitle: loc.sublabel == null ? null : Text(loc.sublabel!),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 18),
                    onPressed: () => _confirmRemove(context, ref, loc),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
