// lib/features/weather/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/domain/settings.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/domain/sky.dart';
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
  // Created with the first list of places, so it can open on the place
  // looked at last (audit about-face-09) instead of always the first.
  PageController? _pageCtl;
  PageController get _page => _pageCtl!;
  int _index = 0;
  double? _overlayHeight;

  @override
  void dispose() {
    _pageCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Places overview can ask Home to jump to a city; animate there, then
    // clear the request.
    ref.listen<String?>(selectedCityIdProvider, (_, id) {
      if (id == null) return;
      final locs = ref.read(savedLocationsProvider).valueOrNull ?? const [];
      final idx = locs.indexWhere((l) => l.id == id);
      if (idx >= 0 && _pageCtl != null && _page.hasClients) {
        _page.animateToPage(idx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic);
        setState(() => _index = idx);
      }
      ref.read(selectedCityIdProvider.notifier).state = null;
    });

    final async = ref.watch(savedLocationsProvider);
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => OhErrorState.fromError(e,
            stackTrace: st,
            title: 'Couldn’t open your saved places',
            onRetry: () => ref.invalidate(savedLocationsProvider)),
        data: (locations) =>
            locations.isEmpty ? const _EmptyState() : _pages(locations),
      ),
    );
  }

  Widget _pages(List<SavedLocation> locations) {
    if (_pageCtl == null) {
      final last = ref
          .read(sharedPreferencesProvider)
          .getString(SettingsPrefsKeys.lastPlaceId);
      final i = locations.indexWhere((l) => l.id == last);
      _index = i < 0 ? 0 : i;
      _pageCtl = PageController(initialPage: _index);
    }
    final clamped = _index.clamp(0, locations.length - 1);
    final multi = locations.length > 1;
    final topPad = MediaQuery.of(context).padding.top;
    // The forecast scrolls full-bleed under the status bar, so pad its top to
    // clear the overlay: the control row, plus the city tabs when there's >1
    // place. The overlay's real height is measured, because at large text
    // the labelled chips wrap onto a second line; until the first
    // measurement, estimate one row.
    final inset = _overlayHeight ?? topPad + 56 + (multi ? 44 : 0);

    return Stack(
      children: [
        PageView(
          controller: _page,
          onPageChanged: (i) {
            setState(() => _index = i);
            // Remembered on this device only, like the places themselves.
            ref
                .read(sharedPreferencesProvider)
                .setString(SettingsPrefsKeys.lastPlaceId, locations[i].id);
          },
          children: [
            for (final loc in locations)
              ForecastView(location: loc, topInset: inset),
          ],
        ),
        // The overlay follows the forecast column's cap, so on a wide
        // window the controls sit above the forecast, not in a far corner.
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OhPage.phoneMaxWidth),
            child: _ReportHeight(
              onHeight: (h) {
                if (mounted && h != _overlayHeight) {
                  setState(() => _overlayHeight = h);
                }
              },
              // Top only: the measured height must not include the
              // bottom inset (a gesture bar would push the forecast down).
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TopControls(onSky: true),
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
            ),
          ),
        ),
      ],
    );
  }
}

/// Reports its child's laid-out height after the frame, so Home can pad the
/// forecast to clear an overlay whose height depends on the text scale.
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onHeight, super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
          BuildContext context, _RenderReportHeight renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);
  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _last) return;
    _last = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}

/// The row of controls over Home: Places, Settings and the theme. Drawn over
/// the sky (frosted) and over the first-run empty state (plain), so Settings,
/// the privacy screen and the theme are reachable before any request is sent.
class _TopControls extends ConsumerWidget {
  const _TopControls({required this.onSky});

  /// Over the living sky the controls are white on a frosted chip; over the
  /// plain app surface they take the theme's colours.
  final bool onSky;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final fg = onSky ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      // Wrap, not Row: at large text the three chips take a second line
      // instead of overflowing.
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            _GlassChip(
              icon: LucideIcons.mapPin,
              label: 'Places',
              onSky: onSky,
              onTap: () => context.push('/places'),
            ),
            _GlassChip(
              icon: LucideIcons.settings,
              label: 'Settings',
              onSky: onSky,
              onTap: () => context.push('/settings'),
            ),
            Material(
              color: _chipColor(context, onSky),
              shape: const StadiumBorder(),
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: OhThemeToggle(
                  value: theme,
                  onChanged: ref.read(settingsProvider.notifier).setTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _chipColor(BuildContext context, bool onSky) => onSky
    ? Colors.black.withValues(alpha: frostedChipAlpha)
    : Theme.of(context).colorScheme.surfaceContainerHighest;

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
    // A scrolling Row, not a fixed 38 dp strip: the pills take the height
    // their names need, so large text grows them instead of clipping.
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < locations.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _tab(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final sel = i == current;
    final loc = locations[i];
    return GestureDetector(
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
              alpha: sel ? frostedChipSelectedAlpha : frostedChipAlpha),
          borderRadius: BorderRadius.circular(999),
          border: sel
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.55), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loc.isCurrent) ...[
              const Icon(LucideIcons.navigation, size: 13, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              loc.label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A frosted chip carrying an icon and a word. A tooltip needs a pointer, so
/// the word is the control's name (audit finding 5; fleet top-bar ruling).
class _GlassChip extends StatelessWidget {
  const _GlassChip(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.onSky});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool onSky;
  @override
  Widget build(BuildContext context) {
    final fg = onSky ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: _chipColor(context, onSky),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: fg)),
              ],
            ),
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
    // Controls on top, then the invitation centred in what is left. The
    // invitation scrolls, so at large text it grows instead of overflowing
    // (and never slides under the controls).
    return OhPage(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _TopControls(onSky: false),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.cloudSun,
                              size: 56,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 16),
                          Text('Add your first place',
                              textAlign: TextAlign.center,
                              style: t.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            'Search for a town or use your location. Its forecast appears here.',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
