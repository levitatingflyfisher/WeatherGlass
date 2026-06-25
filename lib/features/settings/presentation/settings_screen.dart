// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/domain/units.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Label('Units'),
          const SizedBox(height: 8),
          SegmentedButton<UnitSystem>(
            segments: const [
              ButtonSegment(value: UnitSystem.metric, label: Text('Metric')),
              ButtonSegment(value: UnitSystem.imperial, label: Text('Imperial')),
            ],
            selected: {s.units},
            onSelectionChanged: (v) => ctrl.setUnits(v.first),
          ),
          const SizedBox(height: 6),
          Text('°C, km/h, mm  vs  °F, mph, in. Always requested in metric and '
              'converted here, so your choice never changes the request.',
              style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),

          const _Label('Appearance'),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
          ),
          const SizedBox(height: 24),

          const _Label('Privacy & data'),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: Icon(LucideIcons.shieldCheck, color: cs.primary),
              title: const Text('What leaves your device'),
              subtitle: Text('Location precision · the exact request · '
                  'what we never send', style: t.bodySmall),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push('/privacy'),
            ),
          ),
          const SizedBox(height: 24),

          const _Label('About'),
          const SizedBox(height: 8),
          Text('WeatherGlass', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            'A calm, local-first weather app for the home. Free and open-source. '
            'Weather data by Open-Meteo.com (CC BY 4.0).',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}
