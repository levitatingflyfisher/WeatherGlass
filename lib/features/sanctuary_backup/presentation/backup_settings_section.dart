import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:glass/shared/widgets/section_label.dart';

/// WeatherGlass-native backup settings section.
///
/// The package ships a ready-made [BackupSettingsSection] (Divider + bare
/// Material `ListTile`s); WeatherGlass draws the same tile set in its own
/// [SectionLabel] + `Card` + Lucide-icon style, delegating every bit of
/// state/crypto/orchestration logic to [BackupFlow] (seed setup / show words
/// / export / restore / remove words) and [backupControllerProvider] — no
/// auth/crypto state machine, and no copy of the restore orchestration, is
/// reinvented (SANCTUARY-BRIEF §4.W2). Its tiles and wording track the
/// package's (sanctuary_backup_ui 0.3.0); compare them when the package moves.
///
/// The heading is drawn here, in every state, so it can never outlive its
/// tiles: loading shows a status line, and a failed read says so with Try
/// again (audit humane-interface-08 and seven more lenses: Settings used to
/// print the heading while this returned `SizedBox.shrink()`).
class GlassBackupSection extends ConsumerWidget {
  const GlassBackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final authAsync = ref.watch(authNotifierProvider);
    final backupState = ref.watch(backupControllerProvider);
    final isLoading = backupState is AsyncLoading;

    Widget withHeading(Widget body) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Backup'),
            const SizedBox(height: 4),
            body,
          ],
        );

    return authAsync.when(
      loading: () => withHeading(const Card(
        child: ListTile(
          leading: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Checking backup status…'),
        ),
      )),
      error: (e, _) => withHeading(Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(LucideIcons.circleAlert, color: cs.error),
              title: const Text(
                  "Couldn’t read your backup settings on this device."),
              subtitle: const Text('Your places and settings are not '
                  'affected.'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton(
                onPressed: () => ref.invalidate(authNotifierProvider),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      )),
      data: (authState) {
        final hasKey = authState.masterEncryptionKey != null;
        final seedAcked = authState.seedAcknowledged;

        return withHeading(Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Set up seed phrase (only if no key yet).
              if (!hasKey)
                ListTile(
                  leading: Icon(LucideIcons.key, color: cs.primary),
                  title: const Text('Set up encrypted backup'),
                  subtitle: const Text(
                    'Generate 12 recovery words to protect your data',
                  ),
                  enabled: !isLoading,
                  onTap: () => const BackupFlow().runSeedSetup(context, ref),
                ),

              // Mid-setup recovery: key exists but acknowledgement was never
              // completed (user dismissed the re-entry dialog).
              if (hasKey && !seedAcked)
                ListTile(
                  leading: Icon(LucideIcons.pencilLine, color: cs.primary),
                  title: const Text('Complete backup setup'),
                  subtitle: const Text(
                    'Re-enter your recovery words to finish setup',
                  ),
                  enabled: !isLoading,
                  onTap: () =>
                      const BackupFlow().confirmPhraseReEntry(context, ref),
                ),

              // The words stored on this device, shown again behind a
              // confirm: a mistranscribed paper copy otherwise loops forever
              // at the re-entry check.
              if (hasKey)
                ListTile(
                  leading: Icon(LucideIcons.eye, color: cs.primary),
                  title: const Text('Show my recovery words'),
                  subtitle: const Text('To check or replace your paper copy'),
                  enabled: !isLoading,
                  onTap: () =>
                      const BackupFlow().showRecoveryWords(context, ref),
                ),

              // Export (available after seed acknowledged).
              if (hasKey && seedAcked)
                ListTile(
                  leading: Icon(LucideIcons.upload, color: cs.primary),
                  title: const Text('Export backup'),
                  subtitle: authState.lastBackupAt != null
                      ? Text(
                          'Last backup: ${_formatDate(authState.lastBackupAt!)}')
                      : const Text(
                          'Save an encrypted copy of your places and settings'),
                  enabled: !isLoading,
                  onTap: () => const BackupFlow().runExport(context, ref),
                ),

              // Restore (always available).
              ListTile(
                leading: Icon(LucideIcons.download, color: cs.primary),
                title: const Text('Restore from backup'),
                subtitle:
                    const Text('Load places and settings from a backup file'),
                enabled: !isLoading,
                onTap: () => const BackupFlow().runRestore(context, ref),
              ),

              // The snapshot vault (always available: restores and exports
              // populate it regardless of auth state).
              ListTile(
                leading: Icon(LucideIcons.history, color: cs.primary),
                title: const Text('Previous backups'),
                subtitle: const Text(
                    'Snapshots kept on this device. Restore or pin them.'),
                enabled: !isLoading,
                onTap: () => showBackupVaultSheet(context),
              ),

              // Plaintext export (needs no key: sovereignty means you can
              // READ your data, not just recover it).
              ListTile(
                leading: Icon(LucideIcons.fileJson, color: cs.primary),
                title: const Text('Export as plain JSON'),
                subtitle: const Text('Unencrypted, so any program can read it'),
                enabled: !isLoading,
                onTap: () =>
                    const BackupFlow().runPlaintextExport(context, ref),
              ),

              // Remove recovery words (danger zone, only if key exists).
              if (hasKey)
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: cs.error),
                  title: Text('Remove recovery words',
                      style: TextStyle(color: cs.error)),
                  subtitle:
                      const Text('From this device only. Your data stays.'),
                  enabled: !isLoading,
                  onTap: () =>
                      const BackupFlow().runResetIdentity(context, ref),
                ),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ));
      },
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
