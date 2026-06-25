// lib/features/weather/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/weather/presentation/add_location_sheet.dart';
import 'package:glass/features/weather/presentation/forecast_view.dart';

/// Home: one swipeable page of weather per saved place, the sky full-bleed
/// behind everything. The controls are frosted "glass" chips so they read on
/// any sky, light or dark.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(savedLocationsProvider);
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (locations) =>
            locations.isEmpty ? const _EmptyState() : _pages(locations),
      ),
    );
  }

  Widget _pages(List<SavedLocation> locations) {
    final clamped = _index.clamp(0, locations.length - 1);
    final multi = locations.length > 1;
    final topPad = MediaQuery.of(context).padding.top;
    // The forecast scrolls full-bleed under the status bar, so pad its top to
    // clear the overlay: the icon row, plus the city tabs when there's >1 place.
    final inset = topPad + 50 + (multi ? 44 : 0);

    return Stack(
      children: [
        PageView(
          controller: _page,
          onPageChanged: (i) => setState(() => _index = i),
          children: [
            for (final loc in locations)
              ForecastView(location: loc, topInset: inset),
          ],
        ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Spacer(),
                    _GlassIconButton(
                      icon: LucideIcons.mapPin,
                      tooltip: 'Places',
                      onTap: () => context.push('/places'),
                    ),
                    const SizedBox(width: 8),
                    _GlassIconButton(
                      icon: LucideIcons.settings,
                      tooltip: 'Settings',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
              // Named, tappable city tabs — the obvious way to switch places
              // (and to see at a glance that you have more than one).
              if (multi)
                _CityTabs(
                  locations: locations,
                  current: clamped,
                  onSelect: (i) => _page.animateToPage(i,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A horizontal strip of frosted city pills — the current place highlighted —
/// so switching between saved places is one obvious tap (not a hidden swipe).
class _CityTabs extends StatelessWidget {
  const _CityTabs(
      {required this.locations, required this.current, required this.onSelect});
  final List<SavedLocation> locations;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: locations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == current;
          final loc = locations[i];
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: sel ? 0.34 : 0.18),
                borderRadius: BorderRadius.circular(19),
                border: sel
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.55), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loc.isCurrent) ...[
                    Icon(LucideIcons.navigation,
                        size: 13,
                        color: Colors.white.withValues(alpha: sel ? 0.95 : 0.7)),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    loc.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: sel ? 0.98 : 0.74),
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton(
      {required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.20),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudSun,
                size: 56,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Add your first place', style: t.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Search for a town or use your location — its forecast appears here.',
              textAlign: TextAlign.center,
              style: t.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showAddLocationSheet(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add a place'),
            ),
          ],
        ),
      ),
    );
  }
}
