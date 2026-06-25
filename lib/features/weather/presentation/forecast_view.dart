// lib/features/weather/presentation/forecast_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/domain/sky.dart';
import 'package:glass/features/weather/domain/units.dart';
import 'package:glass/features/weather/domain/weather_code.dart';

/// One location's weather, painted on a sky drawn from its real current
/// conditions and time of day. This is WeatherGlass's signature surface.
class ForecastView extends ConsumerWidget {
  const ForecastView({super.key, required this.location});
  final SavedLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final async = ref.watch(forecastProvider(location.id));

    return async.when(
      data: (f) => _Loaded(location: location, forecast: f, units: units),
      loading: () => _SkyBackground(
        palette: skyFor(WeatherCondition.partlyCloudy, true),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _SkyBackground(
        palette: skyFor(WeatherCondition.overcast, true),
        child: _ErrorBody(
          message: '$e',
          onRetry: () => ref.invalidate(forecastProvider(location.id)),
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.location,
    required this.forecast,
    required this.units,
  });
  final SavedLocation location;
  final Forecast forecast;
  final UnitSystem units;

  Future<void> _refresh(WidgetRef ref) async {
    final repo = ref.read(weatherRepositoryProvider);
    await repo.getForecast(location, force: true);
    ref.invalidate(forecastProvider(location.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = forecast.current;
    final palette = skyFor(c.condition, c.isDay);
    final today = forecast.daily.isNotEmpty ? forecast.daily.first : null;

    // The hourly window: from the current hour, the next 24 entries.
    final fromHour = DateTime(
        c.time.year, c.time.month, c.time.day, c.time.hour);
    final hours = forecast.hourly
        .where((h) => !h.time.isBefore(fromHour))
        .take(24)
        .toList();

    return _SkyBackground(
      palette: palette,
      child: RefreshIndicator(
        color: palette.ink,
        backgroundColor: palette.top.withValues(alpha: 0.9),
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _CurrentBlock(
                location: location, current: c, today: today, units: units,
                palette: palette),
            const SizedBox(height: 20),
            _DetailChips(current: c, units: units, palette: palette),
            const SizedBox(height: 24),
            if (hours.isNotEmpty) ...[
              _SectionLabel('Next hours', palette: palette),
              const SizedBox(height: 8),
              _HourlyStrip(hours: hours, units: units, palette: palette),
              const SizedBox(height: 24),
            ],
            _SectionLabel('7 days', palette: palette),
            const SizedBox(height: 8),
            _DailyList(days: forecast.daily, units: units, palette: palette),
            const SizedBox(height: 24),
            _Attribution(palette: palette),
          ],
        ),
      ),
    );
  }
}

class _SkyBackground extends StatelessWidget {
  const _SkyBackground({required this.palette, required this.child});
  final SkyPalette palette;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.gradient,
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _CurrentBlock extends StatelessWidget {
  const _CurrentBlock({
    required this.location,
    required this.current,
    required this.today,
    required this.units,
    required this.palette,
  });
  final SavedLocation location;
  final CurrentConditions current;
  final DailyPoint? today;
  final UnitSystem units;
  final SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (location.isCurrent) ...[
              Icon(LucideIcons.navigation, size: 15, color: palette.dimInk),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(location.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLarge?.copyWith(color: palette.ink)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Icon(iconFor(current.condition, current.isDay),
            size: 76, color: palette.ink),
        const SizedBox(height: 8),
        Text(formatTemp(current.temperatureC, units),
            style: t.displayLarge
                ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700)),
        Text(current.condition.label,
            style: t.titleMedium?.copyWith(color: palette.ink)),
        const SizedBox(height: 4),
        Text(
          [
            'Feels ${formatTemp(current.apparentC, units)}',
            if (today != null)
              'H:${formatTemp(today!.highC, units)}  L:${formatTemp(today!.lowC, units)}',
          ].join('   ·   '),
          style: t.bodyMedium?.copyWith(color: palette.dimInk),
        ),
      ],
    );
  }
}

class _DetailChips extends StatelessWidget {
  const _DetailChips(
      {required this.current, required this.units, required this.palette});
  final CurrentConditions current;
  final UnitSystem units;
  final SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
            icon: LucideIcons.wind,
            label: 'Wind',
            value: formatWind(current.windKmh, units),
            palette: palette),
        const SizedBox(width: 10),
        _Chip(
            icon: LucideIcons.droplets,
            label: 'Humidity',
            value: '${current.humidity}%',
            palette: palette),
        const SizedBox(width: 10),
        _Chip(
            icon: LucideIcons.cloudRain,
            label: 'Rain',
            value: formatPrecip(current.precipMm, units),
            palette: palette),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.palette});
  final IconData icon;
  final String label;
  final String value;
  final SkyPalette palette;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: palette.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: palette.dimInk),
            const SizedBox(height: 6),
            Text(value,
                style: t.titleSmall?.copyWith(color: palette.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: t.labelSmall?.copyWith(color: palette.dimInk)),
          ],
        ),
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip(
      {required this.hours, required this.units, required this.palette});
  final List<HourlyPoint> hours;
  final UnitSystem units;
  final SkyPalette palette;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hourFmt = DateFormat('ha'); // 3PM
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final h = hours[i];
          return Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: palette.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(i == 0 ? 'Now' : hourFmt.format(h.time).toLowerCase(),
                    style: t.labelSmall?.copyWith(color: palette.dimInk)),
                Icon(iconFor(h.condition, _isDayish(h.time)),
                    size: 20, color: palette.ink),
                Text('${h.precipProbability}%',
                    style: t.labelSmall?.copyWith(
                        color: h.precipProbability >= 30
                            ? palette.ink
                            : palette.dimInk.withValues(alpha: 0.6))),
                Text(formatTemp(h.temperatureC, units),
                    style: t.titleSmall?.copyWith(color: palette.ink)),
              ],
            ),
          );
        },
      ),
    );
  }

  // Without per-hour is_day from the API, treat 6:00–19:59 as daytime for icons.
  bool _isDayish(DateTime t) => t.hour >= 6 && t.hour < 20;
}

class _DailyList extends StatelessWidget {
  const _DailyList(
      {required this.days, required this.units, required this.palette});
  final List<DailyPoint> days;
  final UnitSystem units;
  final SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dayFmt = DateFormat('EEE');
    return Container(
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(i == 0 ? 'Today' : dayFmt.format(days[i].date),
                        style: t.titleSmall?.copyWith(color: palette.ink)),
                  ),
                  Icon(iconFor(days[i].condition, true),
                      size: 20, color: palette.ink),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                        days[i].precipProbabilityMax >= 10
                            ? '${days[i].precipProbabilityMax}%'
                            : '',
                        style: t.labelSmall?.copyWith(color: palette.dimInk)),
                  ),
                  const Spacer(),
                  Text(formatTemp(days[i].lowC, units),
                      style: t.bodyMedium?.copyWith(color: palette.dimInk)),
                  const SizedBox(width: 10),
                  Text(formatTemp(days[i].highC, units),
                      style: t.titleSmall?.copyWith(color: palette.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.palette});
  final String text;
  final SkyPalette palette;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.dimInk, letterSpacing: 1.2)),
      );
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.palette});
  final SkyPalette palette;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => context.push('/privacy'),
          icon: Icon(LucideIcons.shieldCheck, size: 16, color: palette.dimInk),
          label: Text('What leaves your device',
              style: t.labelMedium?.copyWith(color: palette.dimInk)),
        ),
        Text('Weather data by Open-Meteo.com  ·  CC BY 4.0',
            style: t.labelSmall?.copyWith(
                color: palette.dimInk.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cloudOff, size: 44),
            const SizedBox(height: 12),
            Text("Couldn't reach the sky.",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
