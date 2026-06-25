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
    return Stack(
      children: [
        PageView(
          controller: _page,
          onPageChanged: (i) => setState(() => _index = i),
          children: [
            for (final loc in locations) ForecastView(location: loc),
          ],
        ),
        // Top controls overlay.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                if (locations.length > 1)
                  _GlassChip(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < locations.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == clamped ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: i == clamped ? 0.95 : 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
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
        ),
      ],
    );
  }
}

/// A frosted dark pill that keeps white icons legible on any sky.
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
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
            Text('Read the sky.', style: t.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add a place to begin. WeatherGlass keeps everything on your device and '
              'rounds your location to a coarse cell before it ever asks.',
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
