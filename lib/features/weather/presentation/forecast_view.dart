// lib/features/weather/presentation/forecast_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
  const ForecastView({super.key, required this.location, this.topInset = 8});
  final SavedLocation location;

  /// Space to leave at the top so the scrolling content clears the home's
  /// overlay (status bar + the city switcher + icon controls).
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).units;
    final async = ref.watch(forecastProvider(location.id));

    return async.when(
      data: (f) => _Loaded(
          location: location, forecast: f, units: units, topInset: topInset),
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
    this.topInset = 8,
  });
  final SavedLocation location;
  final Forecast forecast;
  final UnitSystem units;
  final double topInset;

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
          padding: EdgeInsets.fromLTRB(20, topInset, 20, 28),
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
              _HourlyGraph(hours: hours, units: units, palette: palette),
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

/// The next-24-hours temperature as a smooth curve (Tufte: the line shows the
/// trend, the labels give the values) with a soft gradient fill, condition
/// glyphs, and precipitation as quiet bars — instead of a row of number boxes.
/// Scrolls horizontally; the curve is scaled to the window's own min/max so the
/// shape of the day is legible.
class _HourlyGraph extends StatelessWidget {
  const _HourlyGraph(
      {required this.hours, required this.units, required this.palette});
  final List<HourlyPoint> hours;
  final UnitSystem units;
  final SkyPalette palette;

  static const _hourW = 54.0;
  static const _height = 172.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: CustomPaint(
          size: Size(_hourW * hours.length, _height),
          painter: _HourlyPainter(
            hours: hours,
            units: units,
            palette: palette,
            hourW: _hourW,
          ),
        ),
      ),
    );
  }
}

class _HourlyPainter extends CustomPainter {
  _HourlyPainter({
    required this.hours,
    required this.units,
    required this.palette,
    required this.hourW,
  });
  final List<HourlyPoint> hours;
  final UnitSystem units;
  final SkyPalette palette;
  final double hourW;

  // Vertical bands within the height.
  static const _iconY = 18.0;
  static const _curveTop = 64.0; // hottest hour sits here
  static const _curveBottom = 104.0; // coldest hour sits here
  static const _precipBase = 150.0; // precip bars grow up from here
  static const _precipMax = 22.0;
  static const _labelY = 156.0;

  bool _isDayish(DateTime t) => t.hour >= 6 && t.hour < 20;

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;
    final temps = hours.map((h) => h.temperatureC).toList();
    final lo = temps.reduce((a, b) => a < b ? a : b);
    final hi = temps.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 0.5 ? 1.0 : hi - lo;

    double x(int i) => i * hourW + hourW / 2;
    double y(double tC) =>
        _curveTop + (1 - (tC - lo) / span) * (_curveBottom - _curveTop);

    final pts = [for (var i = 0; i < hours.length; i++) Offset(x(i), y(temps[i]))];

    // Gradient fill under the curve.
    final curve = _smooth(pts);
    final fill = Path.from(curve)
      ..lineTo(pts.last.dx, _precipBase)
      ..lineTo(pts.first.dx, _precipBase)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.ink.withValues(alpha: 0.22),
            palette.ink.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, _curveTop, size.width, _precipBase - _curveTop)),
    );
    // The curve itself.
    canvas.drawPath(
      curve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = palette.ink.withValues(alpha: 0.85),
    );

    for (var i = 0; i < hours.length; i++) {
      final h = hours[i];
      final cx = x(i);
      // Condition glyph (top row).
      _icon(canvas, iconFor(h.condition, _isDayish(h.time)),
          Offset(cx, _iconY), 19, palette.ink.withValues(alpha: 0.9));
      // Temperature label, floating just above its point (label-on-data).
      _text(canvas, formatTemp(h.temperatureC, units), Offset(cx, pts[i].dy - 18),
          13, FontWeight.w600, palette.ink);
      // Precipitation bar (only when it's worth noting).
      if (h.precipProbability >= 5) {
        final barH = (h.precipProbability / 100) * _precipMax;
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3, _precipBase - barH, 6, barH),
          const Radius.circular(2),
        );
        canvas.drawRRect(
            r, Paint()..color = palette.ink.withValues(alpha: 0.28));
        if (h.precipProbability >= 30) {
          _text(canvas, '${h.precipProbability}%',
              Offset(cx, _precipBase - barH - 9), 9.5, FontWeight.w500,
              palette.dimInk);
        }
      }
      // Hour label.
      _text(canvas, i == 0 ? 'Now' : DateFormat('ha').format(h.time).toLowerCase(),
          Offset(cx, _labelY), 11, FontWeight.w500, palette.dimInk);
    }
  }

  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = p[i == 0 ? 0 : i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = p[i + 2 < p.length ? i + 2 : p.length - 1];
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _icon(Canvas c, IconData icon, Offset center, double sz, Color color) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: sz,
            color: color),
      ),
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _text(Canvas c, String s, Offset center, double sz, FontWeight w, Color color) {
    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: sz, fontWeight: w, color: color)),
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HourlyPainter old) =>
      old.hours != hours || old.palette.ink != palette.ink || old.units != units;
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
    // The whole week's span anchors every bar, so a warm day reads as a bar to
    // the right and a cold one to the left (Apple's range-bar idea).
    final weekLo = days.map((d) => d.lowC).reduce((a, b) => a < b ? a : b);
    final weekHi = days.map((d) => d.highC).reduce((a, b) => a > b ? a : b);
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
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(i == 0 ? 'Today' : dayFmt.format(days[i].date),
                        style: t.titleSmall?.copyWith(color: palette.ink)),
                  ),
                  Icon(iconFor(days[i].condition, true),
                      size: 20, color: palette.ink),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 30,
                    child: Text(
                        days[i].precipProbabilityMax >= 10
                            ? '${days[i].precipProbabilityMax}%'
                            : '',
                        style: t.labelSmall?.copyWith(color: palette.dimInk)),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 30,
                    child: Text(formatTemp(days[i].lowC, units),
                        textAlign: TextAlign.right,
                        style: t.bodyMedium?.copyWith(color: palette.dimInk)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RangeBar(
                      lo: days[i].lowC,
                      hi: days[i].highC,
                      weekLo: weekLo,
                      weekHi: weekHi,
                      track: palette.ink.withValues(alpha: 0.12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(formatTemp(days[i].highC, units),
                        style: t.titleSmall?.copyWith(color: palette.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A day's low→high temperature as a bar, placed and sized against the whole
/// week's range and tinted by a cold→warm ramp. Encodes three things at a
/// glance: how warm the day is (where the bar sits), its swing (how long), and
/// roughly the temperatures (its colour).
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.lo,
    required this.hi,
    required this.weekLo,
    required this.weekHi,
    required this.track,
  });
  final double lo, hi, weekLo, weekHi;
  final Color track;

  static Color _temp(double c) {
    const cold = Color(0xFF6CA6E0), teal = Color(0xFF7BC0B6);
    const gold = Color(0xFFD9C24E), amber = Color(0xFFE0883D), hot = Color(0xFFD9603A);
    if (c <= 0) return cold;
    if (c <= 10) return Color.lerp(cold, teal, c / 10)!;
    if (c <= 20) return Color.lerp(teal, gold, (c - 10) / 10)!;
    if (c <= 30) return Color.lerp(gold, amber, (c - 20) / 10)!;
    if (c <= 38) return Color.lerp(amber, hot, (c - 30) / 8)!;
    return hot;
  }

  @override
  Widget build(BuildContext context) {
    final span = (weekHi - weekLo) < 1 ? 1.0 : weekHi - weekLo;
    final a = ((lo - weekLo) / span).clamp(0.0, 1.0);
    final b = ((hi - weekLo) / span).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final left = a * w;
      final width = ((b - a) * w).clamp(10.0, w);
      return SizedBox(
        height: 7,
        child: Stack(
          children: [
            // The week-range track.
            Container(
              decoration: BoxDecoration(
                  color: track, borderRadius: BorderRadius.circular(4)),
            ),
            Positioned(
              left: left,
              width: width,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [_temp(lo), _temp(hi)]),
                ),
              ),
            ),
          ],
        ),
      );
    });
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
    return Center(
      child: Text('Weather data by Open-Meteo.com  ·  CC BY 4.0',
          style: t.labelSmall
              ?.copyWith(color: palette.dimInk.withValues(alpha: 0.7))),
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
