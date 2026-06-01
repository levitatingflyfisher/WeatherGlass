// lib/features/weather/presentation/add_location_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/data/geolocation_service.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/domain/geo.dart';

Future<void> showAddLocationSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddLocationSheet(),
    );

class AddLocationSheet extends ConsumerStatefulWidget {
  const AddLocationSheet({super.key});
  @override
  ConsumerState<AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends ConsumerState<AddLocationSheet> {
  final _query = TextEditingController();
  final _geo = GeolocationService();
  List<GeoPlace> _results = const [];
  bool _searching = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await ref.read(openMeteoProvider).searchPlaces(q);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Search failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addPlace(GeoPlace p) async {
    final precision = ref.read(settingsProvider).precision;
    // Round at the boundary — only the coarse cell is ever stored or queried.
    final (lat, lon) = roundForPrecision(p.latitude, p.longitude, precision);
    await ref.read(locationsRepositoryProvider).add(
          label: p.name,
          sublabel: p.region.isEmpty ? null : p.region,
          lat: lat,
          lon: lon,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _locateMe() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final fix = await _geo.currentCoarse();
      if (fix == null) {
        if (mounted) {
          setState(() => _error =
              'Location unavailable. Search for a place instead.');
        }
        return;
      }
      final precision = ref.read(settingsProvider).precision;
      final (lat, lon) = roundForPrecision(fix.lat, fix.lon, precision);
      await ref.read(locationsRepositoryProvider).upsertCurrent(
            label: 'My location',
            lat: lat,
            lon: lon,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final precision = ref.watch(settingsProvider).precision;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a place', style: t.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search a town or city',
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(LucideIcons.cornerDownLeft),
                      onPressed: _search),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _locating ? null : _locateMe,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.navigation, size: 18),
            label: const Text('Use my location (approximate)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: t.bodySmall?.copyWith(color: cs.error)),
          ],
          const SizedBox(height: 8),
          if (_results.isNotEmpty)
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final p = _results[i];
                  return ListTile(
                    leading: const Icon(LucideIcons.mapPin),
                    title: Text(p.name),
                    subtitle: p.region.isEmpty ? null : Text(p.region),
                    onTap: () => _addPlace(p),
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Saved places are rounded to a ${precision.cell} cell before '
                  'anything is sent.',
                  style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
