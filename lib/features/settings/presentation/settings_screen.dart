// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:glass/features/sanctuary_backup/presentation/backup_settings_section.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/features/weather/domain/units.dart';
import 'package:glass/shared/widgets/section_label.dart';

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
      body: OhPage(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Unfinished backup setup gets a dismissible reminder (fleet
            // ruling 48). Here, not on Home: the forecast stays calm. It
            // renders nothing once setup is finished or while dismissed.
            const BackupSetupReminder(),
            const SectionLabel('Units'),
            const SizedBox(height: 8),
            SegmentedButton<UnitSystem>(
              segments: const [
                ButtonSegment(value: UnitSystem.metric, label: Text('Metric')),
                ButtonSegment(
                    value: UnitSystem.imperial, label: Text('Imperial')),
              ],
              selected: {s.units},
              onSelectionChanged: (v) => ctrl.setUnits(v.first),
            ),
            const SizedBox(height: 6),
            Text(
                '°C, km/h, mm or °F, mph, in. Always requested in metric and '
                'converted here, so your choice never changes the request.',
                style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            const SectionLabel('Appearance'),
            const SizedBox(height: 8),
            SegmentedButton<OhThemeModePreference>(
              segments: [
                for (final p in OhThemeModePreference.values)
                  ButtonSegment(value: p, label: Text(p.shortLabel)),
              ],
              selected: {s.theme},
              onSelectionChanged: (v) => ctrl.setTheme(v.first),
            ),
            const SizedBox(height: 6),
            Text('Auto follows your phone’s light or dark setting.',
                style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            const SectionLabel('Privacy & data'),
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                leading: Icon(LucideIcons.shieldCheck, color: cs.primary),
                title: const Text('What leaves your device'),
                subtitle: Text(
                    'Location precision · the exact request · '
                    'what we never send',
                    style: t.bodySmall),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push('/privacy'),
              ),
            ),
            const SizedBox(height: 24),
            // Draws its own heading, in every state.
            const GlassBackupSection(),
            const SizedBox(height: 24),
            const SectionLabel('About'),
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
      ),
    );
  }
}
