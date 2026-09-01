// lib/features/weather/presentation/forecast_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/storage/app_database.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/data/models.dart';
import 'package:glass/features/weather/domain/freshness.dart';
import 'package:glass/features/weather/domain/sky.dart';
import 'package:glass/features/weather/domain/units.dart';
import 'package:glass/features/weather/domain/weather_code.dart';
import 'package:glass/shared/theme/app_theme.dart';
import 'package:glass/shared/widgets/section_label.dart';

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
      error: (e, st) {
        final palette = skyFor(WeatherCondition.overcast, true);
        return _SkyBackground(
          palette: palette,
          // The failure sits on a sky, not on the app surface, so it takes
          // the theme that matches the sky's brightness: dark-mode text on
          // the pale overcast sky would be unreadable.
          child: Theme(
            data: palette.isDark ? AppTheme.dark : AppTheme.light,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: OhErrorState.fromError(
                e,
                stackTrace: st,
                title: 'Couldn’t reach the sky',
                message: 'WeatherGlass couldn’t reach Open-Meteo for '
                    '${location.label}. Check your connection and try again.',
                onRetry: () => ref.invalidate(forecastProvider(location.id)),
              ),
            ),
          ),
        );
      },
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

  /// One refresh, one fetch attempt: the provider itself reloads with
  /// force, so a failure is not followed by a second fetch (the old code
  /// forced a fetch, then invalidated, and the reload fetched again once the
  /// cache was past its TTL). A failure with a cached copy comes back as the
  /// stale forecast, notice and all.
  Future<void> _refresh(WidgetRef ref) async {
    ref.read(forceRefreshProvider).add(location.id);
    try {
      final reloaded = ref.refresh(forecastProvider(location.id).future);
      await reloaded;
    } catch (_) {
      // Nothing cached: the provider's error state says so.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = forecast.current;
    final palette = skyFor(c.condition, c.isDay);

    // "Now" is the forecast's own current time when it is fresh. A stale
    // forecast's current time is when it was fetched, hours or days ago, so
    // there "now" is the real clock in the place's wall time, and hours and
    // days already past are dropped rather than labelled Now and Today.
    final anchor = forecast.stale
        ? _wallNow(ref.watch(clockProvider)(), forecast.utcOffsetSeconds)
        : c.time;
    final todayDate = DateTime(anchor.year, anchor.month, anchor.day);
    final days =
        forecast.daily.where((d) => !d.date.isBefore(todayDate)).toList();
    final today =
        days.isNotEmpty && days.first.date == todayDate ? days.first : null;

    // The hourly window: from the current hour, the next 24 entries.
    final fromHour =
        DateTime(anchor.year, anchor.month, anchor.day, anchor.hour);
    final hours = forecast.hourly
        .where((h) => !h.time.isBefore(fromHour))
        .take(24)
        .toList();

    return _SkyBackground(
      palette: palette,
      // The sky fills the window; the forecast column is capped and centred
      // so a desktop or tablet does not stretch a phone layout (and the
      // margins still scroll it with a mouse wheel).
      child: OhPage(
        safeArea: false,
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          color: palette.ink,
          backgroundColor: palette.top.withValues(alpha: 0.9),
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, topInset, 20, 28),
            children: [
              if (forecast.stale)
                _StaleNotice(
                  age: forecast.fetchedAt == null
                      ? null
                      : ref
                          .watch(clockProvider)()
                          .difference(forecast.fetchedAt!),
                  palette: palette,
                  onRetry: () => _refresh(ref),
                ),
              _CurrentBlock(
                  location: location,
                  current: c,
                  today: today,
                  units: units,
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
              if (days.isNotEmpty) ...[
                _SectionLabel('7 days', palette: palette),
                const SizedBox(height: 8),
                _DailyList(
                    days: days,
                    today: todayDate,
                    units: units,
                    palette: palette,
                    // The "now" dot only when the current reading is now.
                    currentC: forecast.stale ? null : c.temperatureC),
              ],
              const SizedBox(height: 24),
              _Attribution(
                palette: palette,
                age: forecast.fetchedAt == null
                    ? null
                    : ref
                        .watch(clockProvider)()
                        .difference(forecast.fetchedAt!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The real clock as a naive wall-clock time at the forecast's place, the
/// same form Open-Meteo's `timezone=auto` times are parsed into.
DateTime _wallNow(DateTime now, int utcOffsetSeconds) {
  final w = now.toUtc().add(Duration(seconds: utcOffsetSeconds));
  return DateTime(w.year, w.month, w.day, w.hour, w.minute);
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
              'H:${formatTemp(today!.highC, units)} L:${formatTemp(today!.lowC, units)}',
          ].join(' · '),
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
          color: palette.panel,
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
            Text(label, style: t.labelSmall?.copyWith(color: palette.dimInk)),
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
    final t = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    // The canvas has no layout of its own, so it grows by hand: every band
    // and column scales with the reader's text, measured on the 13 px step.
    final k = scaler.scale(13) / 13;
    return SizedBox(
      height: _height * k,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: CustomPaint(
          size: Size(_hourW * k * hours.length, _height * k),
          painter: HourlyPainter(
            hours: hours,
            units: units,
            palette: palette,
            hourW: _hourW * k,
            textScaler: scaler,
            bandScale: k,
            valueStyle: t.labelMedium!,
            labelStyle: t.labelSmall!,
          ),
        ),
      ),
    );
  }
}

/// Paints the next-24-hours curve. Public only so a test can read what it
/// was given: the reader's text scale and the app's type (audit
/// visual-display-05, mind-in-mind-08).
@visibleForTesting
class HourlyPainter extends CustomPainter {
  HourlyPainter({
    required this.hours,
    required this.units,
    required this.palette,
    required this.hourW,
    required this.textScaler,
    required this.bandScale,
    required this.valueStyle,
    required this.labelStyle,
  });
  final List<HourlyPoint> hours;
  final UnitSystem units;
  final SkyPalette palette;
  final double hourW;

  /// The reader's text scale, applied to every label.
  final TextScaler textScaler;

  /// How much the vertical bands grow with the text (1.0 at default size).
  final double bandScale;

  /// Temperatures (the ladder's 13 px semibold step, in Nunito).
  final TextStyle valueStyle;

  /// Hours and rain chances (the ladder's 13 px step, in Nunito).
  final TextStyle labelStyle;

  // Vertical bands within the height, at text scale 1.0.
  static const _iconY0 = 18.0;
  static const _curveTop0 = 64.0; // hottest hour sits here
  static const _curveBottom0 = 104.0; // coldest hour sits here
  static const _precipBase0 = 150.0; // precip bars grow up from here
  static const _precipMax0 = 22.0;
  static const _labelY0 = 156.0;

  double get _iconY => _iconY0 * bandScale;
  double get _curveTop => _curveTop0 * bandScale;
  double get _curveBottom => _curveBottom0 * bandScale;
  double get _precipBase => _precipBase0 * bandScale;
  double get _precipMax => _precipMax0 * bandScale;
  double get _labelY => _labelY0 * bandScale;

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

    final pts = [
      for (var i = 0; i < hours.length; i++) Offset(x(i), y(temps[i]))
    ];

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
            palette.panelTint.withValues(alpha: 0.28),
            palette.panelTint.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromLTWH(0, _curveTop, size.width, _precipBase - _curveTop)),
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
      _icon(canvas, iconFor(h.condition, _isDayish(h.time)), Offset(cx, _iconY),
          19 * bandScale, palette.ink.withValues(alpha: 0.9));
      // Temperature label, floating just above its point (label-on-data).
      _text(canvas, formatTemp(h.temperatureC, units),
          Offset(cx, pts[i].dy - 18 * bandScale), valueStyle, palette.ink);
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
          _text(
              canvas,
              '${h.precipProbability}%',
              Offset(cx, _precipBase - barH - 10 * bandScale),
              labelStyle,
              palette.dimInk);
        }
      }
      // Hour label.
      _text(
          canvas,
          i == 0 ? 'Now' : DateFormat('ha').format(h.time).toLowerCase(),
          Offset(cx, _labelY),
          labelStyle,
          palette.dimInk);
    }
  }

  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = p[i == 0 ? 0 : i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = p[i + 2 < p.length ? i + 2 : p.length - 1];
      final c1 =
          Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 =
          Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
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

  void _text(Canvas c, String s, Offset center, TextStyle style, Color color) {
    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      text: TextSpan(text: s, style: style.copyWith(color: color)),
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant HourlyPainter old) =>
      old.hours != hours ||
      old.palette.ink != palette.ink ||
      old.units != units ||
      old.textScaler != textScaler ||
      old.valueStyle != valueStyle ||
      old.labelStyle != labelStyle;
}

class _DailyList extends StatelessWidget {
  const _DailyList(
      {required this.days,
      required this.today,
      required this.units,
      required this.palette,
      required this.currentC});
  final List<DailyPoint> days;
  final DateTime today; // date-only, in the place's wall time
  final UnitSystem units;
  final SkyPalette palette;
  final double? currentC; // marks "now" on today's bar (Apple's dot)

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dayFmt = DateFormat('EEE');
    // The whole week's span anchors every bar, so a warm day reads as a bar to
    // the right and a cold one to the left (Apple's range-bar idea).
    final weekLo = days.map((d) => d.lowC).reduce((a, b) => a < b ? a : b);
    final weekHi = days.map((d) => d.highC).reduce((a, b) => a > b ? a : b);
    final scaler = MediaQuery.textScalerOf(context);
    final dayStyle = t.titleSmall?.copyWith(color: palette.ink);
    final pctStyle = t.labelSmall?.copyWith(color: palette.dimInk);
    final loStyle = t.bodyMedium?.copyWith(color: palette.dimInk);
    final hiStyle = t.titleSmall?.copyWith(color: palette.ink);
    String dayName(DailyPoint d) =>
        d.date == today ? 'Today' : dayFmt.format(d.date);
    String pct(DailyPoint d) =>
        d.precipProbabilityMax >= 10 ? '${d.precipProbabilityMax}%' : '';

    double widest(Iterable<String> texts, TextStyle? style) {
      var w = 0.0;
      for (final s in texts) {
        final tp = TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (tp.width > w) w = tp.width;
      }
      return w;
    }

    Widget bar(int i) => _RangeBar(
          key: ValueKey('range-bar-$i'),
          lo: days[i].lowC,
          hi: days[i].highC,
          weekLo: weekLo,
          weekHi: weekHi,
          track: palette.ink.withValues(alpha: 0.12),
          nowC: days[i].date == today ? currentC : null,
          nowRing: palette.top,
        );

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: LayoutBuilder(builder: (context, box) {
        // What the one-line row's text needs at this text scale (paddings
        // 12+8+6+8+8+8+12 and the 20 dp glyph); the bar gets the rest. If
        // that leaves under 48 dp, each day takes two lines instead, so the
        // bar never shrinks to nothing (it reached 0 px at 360 dp x 2.0).
        final textW = widest(days.map(dayName), dayStyle) +
            widest(days.map(pct), pctStyle) +
            widest(days.map((d) => formatTemp(d.lowC, units)), loStyle) +
            widest(days.map((d) => formatTemp(d.highC, units)), hiStyle) +
            20 +
            62;
        if (box.maxWidth - textW < 48) {
          return Column(children: [
            for (var i = 0; i < days.length; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(dayName(days[i]),
                              softWrap: false, style: dayStyle)),
                      Icon(iconFor(days[i].condition, true),
                          size: 20, color: palette.ink),
                      const SizedBox(width: 6),
                      Text(pct(days[i]), softWrap: false, style: pctStyle),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(formatTemp(days[i].lowC, units),
                          softWrap: false, style: loStyle),
                      const SizedBox(width: 8),
                      Expanded(child: bar(i)),
                      const SizedBox(width: 8),
                      Text(formatTemp(days[i].highC, units),
                          softWrap: false, style: hiStyle),
                    ]),
                  ],
                ),
              ),
          ]);
        }
        // A Table, not fixed-width boxes: every text column is as wide as
        // its widest cell at the reader's text scale, and only the range bar
        // gives up width. Fixed widths sized for scale 1.0 broke "Today" into
        // "Tod / ay" at 1.3 (audit mind-in-mind-04/14, visual-display-16).
        return Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
            3: IntrinsicColumnWidth(),
            4: FlexColumnWidth(),
            5: IntrinsicColumnWidth(),
          },
          children: [
            for (var i = 0; i < days.length; i++)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child:
                      Text(dayName(days[i]), softWrap: false, style: dayStyle),
                ),
                Icon(iconFor(days[i].condition, true),
                    size: 20, color: palette.ink),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(pct(days[i]), softWrap: false, style: pctStyle),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(formatTemp(days[i].lowC, units),
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: loStyle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: bar(i),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(formatTemp(days[i].highC, units),
                      softWrap: false, style: hiStyle),
                ),
              ]),
          ],
        );
      }),
    );
  }
}

/// A day's low→high temperature as a bar, placed and sized against the whole
/// week's range and tinted by a cold→warm ramp. Encodes three things at a
/// glance: how warm the day is (where the bar sits), its swing (how long), and
/// roughly the temperatures (its colour).
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    super.key,
    required this.lo,
    required this.hi,
    required this.weekLo,
    required this.weekHi,
    required this.track,
    required this.nowRing,
    this.nowC,
  });
  final double lo, hi, weekLo, weekHi;
  final Color track;
  final Color nowRing;
  final double? nowC; // current temp → a dot on today's bar (Apple's marker)

  static Color _temp(double c) {
    const cold = Color(0xFF6CA6E0), teal = Color(0xFF7BC0B6);
    const gold = Color(0xFFD9C24E),
        amber = Color(0xFFE0883D),
        hot = Color(0xFFD9603A);
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
      // At large text the bar column can be narrower than the old 10 px floor;
      // clamp(10, w) then threw. Keep the floor only where it fits.
      final width = ((b - a) * w).clamp(w < 10 ? w : 10.0, w);
      final children = <Widget>[
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
      ];
      // Apple's marker: where the current temperature sits in today's range.
      if (nowC != null && w >= 9) {
        final f = ((nowC! - weekLo) / span).clamp(0.0, 1.0);
        children.add(Positioned(
          left: (f * w - 4.5).clamp(0.0, w - 9),
          top: -1,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: nowRing, width: 1.5),
            ),
          ),
        ));
      }
      return SizedBox(
        height: 7,
        child: Stack(clipBehavior: Clip.none, children: children),
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
        child: SectionLabel(text, color: palette.dimInk),
      );
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.palette, this.age});
  final SkyPalette palette;

  /// How old the forecast on screen is; a quiet timestamp, so the
  /// household can always tell (null when unknown).
  final Duration? age;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = t.labelSmall?.copyWith(color: palette.dimInk);
    return Column(
      children: [
        if (age != null)
          Text('Updated ${describeAge(age!)}',
              textAlign: TextAlign.center, style: style),
        Text('Weather data by Open-Meteo.com · CC BY 4.0',
            textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

/// Shown above a forecast served from the cache because the fetch failed:
/// the weather stays on screen, with its age and a way to try again (audit
/// humane-interface-05; Forecastie's visible stale marker).
class _StaleNotice extends StatelessWidget {
  const _StaleNotice(
      {required this.age, required this.palette, required this.onRetry});
  final Duration? age;
  final SkyPalette palette;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final when = age == null ? 'earlier' : describeAge(age!);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      // Sentence first, Try again beneath it: at large text a Row left the
      // button no room.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.cloudOff, size: 18, color: palette.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Couldn’t reach Open-Meteo. Showing the forecast from $when.',
                  style: t.bodyMedium?.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: palette.ink,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}
