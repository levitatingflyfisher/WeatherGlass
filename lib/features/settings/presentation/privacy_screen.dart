// lib/features/settings/presentation/privacy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/data/open_meteo_client.dart';
import 'package:glass/features/weather/domain/geo.dart';

/// The soul of WeatherGlass: shows the user *exactly* what a weather request looks
/// like, what is never sent, what genuinely can't be hidden, and lets them
/// dial location precision. No hand-waving — the real URL is on screen.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final precision = ref.watch(settingsProvider).precision;
    final locations = ref.watch(savedLocationsProvider).valueOrNull ?? const [];

    // Show the real request for the first saved place, or a worked example,
    // built exactly as the send path builds it (weather_repository.dart):
    // re-rounded to the current precision, so the two cannot drift even if a
    // stored row were ever finer than the setting.
    final sample = locations.isNotEmpty
        ? (locations.first.lat, locations.first.lon, locations.first.label)
        : (52.52, 13.41, 'an example place');
    final (lat, lon) = roundForPrecision(sample.$1, sample.$2, precision);
    final url = OpenMeteo.forecastUrl(lat, lon).toString();
    final saved = locations.length;

    return Scaffold(
      appBar: AppBar(title: const Text('What leaves your device')),
      // The prose screen gets a narrower column than the 640 dp default, so
      // its 13 px captions stay near 80 characters a line on a wide window
      // (audit design-for-hackers-03 measured a 728 px measure).
      body: OhPage(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Text(
              'WeatherGlass is local-first. Forecasts come straight from Open-Meteo with '
              'no account and no go-between. Here is the whole story.',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            const _Heading('The exact request', icon: LucideIcons.code),
            const SizedBox(height: 8),
            _UrlBox(url: url),
            const SizedBox(height: 6),
            Text(
              // "or coarser": a place saved under a coarser setting stays on
              // its coarser grid (rounding cannot be undone), and the send
              // boundary never sends finer than the setting. Both directions
              // are true of this sentence (audit finding 3).
              'This is the entire forecast request for ${sample.$3}. The only '
              'part that differs between you and anyone else is the '
              'coordinate, rounded to ${precision.cell} or coarser. There is '
              'no key, no token, and nothing that ties it to you.',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            // audit design-of-everyday-things-07: the geocoder is the one
            // request that carries unrounded free text, and the screen that
            // promises the whole story never mentioned it.
            const _Heading('The other request, only when you search',
                icon: LucideIcons.search),
            const SizedBox(height: 8),
            _UrlBox(url: OpenMeteo.geocodeUrl('Berlin').toString()),
            const SizedBox(height: 6),
            Text(
              'Searching for a place asks Open-Meteo’s geocoder, as above for '
              '“Berlin”. The name goes exactly as you type it: it is not '
              'rounded, and nothing else is attached. Only the place you pick '
              'is kept, rounded like any other.',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            const _Heading('Never sent', icon: LucideIcons.shieldCheck),
            const _GoodRow('No API key or app token'),
            const _GoodRow('No cookies'),
            const _GoodRow('No account, login, or email'),
            const _GoodRow('No analytics, ads, or trackers'),
            const _GoodRow('Your places and history stay on this device'),
            const _GoodRow(
                'An encrypted backup goes only to the share sheet you choose, '
                'never to a server of ours'),
            const SizedBox(height: 24),
            const _Heading('Honestly, what we can’t hide',
                icon: LucideIcons.eye),
            const SizedBox(height: 8),
            Text(
              'Any direct request shows the provider your device’s IP address; '
              'that’s how the internet works, and WeatherGlass does not route through a '
              'server of ours to mask it. What WeatherGlass does instead is reveal as '
              'little as possible: a coarse, rounded location and aggressive '
              'caching so it asks rarely. Your set of saved places, seen from one '
              'IP over time, is still loosely correlatable: rounding and caching '
              'shrink that, they don’t erase it.',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            const _Heading('Location precision', icon: LucideIcons.mapPin),
            const SizedBox(height: 4),
            Text(
              'How coarsely your location is rounded before it’s stored or '
              'sent. A coarser setting re-rounds every saved place now; a '
              'finer one applies only to places you add afterwards.',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            RadioGroup<LocationPrecision>(
              groupValue: precision,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setPrecision(v!),
              child: Column(
                children: [
                  for (final p in LocationPrecision.values)
                    RadioListTile<LocationPrecision>(
                      value: p,
                      title: Text(
                          '${p.name[0].toUpperCase()}${p.name.substring(1)}'
                          ' · ${p.cell}'),
                      // A coarser choice destroys detail on disk, so it says
                      // so before the tap, not after (audit
                      // humane-interface-01, about-face-03).
                      subtitle: Text(
                        p.decimals < precision.decimals && saved > 0
                            ? '${p.blurb} Re-rounds your $saved saved '
                                'place${saved == 1 ? '' : 's'} now. Choosing '
                                'a finer setting later won’t bring back the '
                                'detail.'
                            : p.blurb,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Weather data by Open-Meteo.com, licensed CC BY 4.0 '
              '(creativecommons.org/licenses/by/4.0). WeatherGlass is free and '
              'open-source software.',
              style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _UrlBox extends StatelessWidget {
  const _UrlBox({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            url,
            // The ladder's code face: platform monospace on Android, the
            // bundled Nunito on the web, which has no platform fonts. It
            // inherits nothing from the theme, so it is given its colour.
            style: OhTypography.code(color: cs.onSurface)
                .copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request URL copied')),
                  );
                }
              },
              icon: const Icon(LucideIcons.copy, size: 15),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoodRow extends StatelessWidget {
  const _GoodRow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(LucideIcons.check, size: 16, color: Color(0xFF3E9E6E)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
