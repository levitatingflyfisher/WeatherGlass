import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

/// WeatherGlass-native "Backup & Restore" settings section.
///
/// The package ships a ready-made [BackupSettingsSection], but it draws its
/// own `Divider` + "Encrypted Backup" header and bare `ListTile`s, which
/// clashes with WeatherGlass's `_Label` (uppercase caption) + `Card` +
/// `ListTile` convention used by every other settings section (see
/// "Privacy & data" in settings_screen.dart). This widget reproduces the
/// same tile set with WeatherGlass's own presentation, delegating every bit
/// of state/crypto/orchestration logic to [BackupFlow] (seed setup / export /
/// restore / reset) and [backupControllerProvider] — no auth/crypto state
/// machine, and no copy of the ~130-line restore orchestration, is
/// reinvented (SANCTUARY-BRIEF §4.W2; W4 finding: adopt `BackupFlow` instead
/// of a hand-copied flow).
class GlassBackupSection extends ConsumerWidget {
  const GlassBackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final authAsync = ref.watch(authNotifierProvider);
    final backupState = ref.watch(backupControllerProvider);
    final isLoading = backupState is AsyncLoading;

    return authAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (authState) {
        final hasKey = authState.masterEncryptionKey != null;
        final seedAcked = authState.seedAcknowledged;

        return Card(
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
                subtitle: const Text(
                    'Load places and settings from an .ohbk file'),
                enabled: !isLoading,
                onTap: () => const BackupFlow().runRestore(context, ref),
              ),

              // The snapshot vault (always available: restores and exports
              // populate it regardless of auth state).
              ListTile(
                leading: Icon(LucideIcons.history, color: cs.primary),
                title: const Text('Previous backups'),
                subtitle: const Text(
                    'Snapshots kept on this device — restore or pin them'),
                enabled: !isLoading,
                onTap: () => showBackupVaultSheet(context),
              ),

              // Plaintext export (needs no key: sovereignty means you can
              // READ your data, not just recover it).
              ListTile(
                leading: Icon(LucideIcons.fileJson, color: cs.primary),
                title: const Text('Export as plain JSON'),
                subtitle:
                    const Text('Unencrypted — readable by any program'),
                enabled: !isLoading,
                onTap: () =>
                    const BackupFlow().runPlaintextExport(context, ref),
              ),

              // Reset identity (danger zone, only if key exists).
              if (hasKey)
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: cs.error),
                  title: Text('Reset identity', style: TextStyle(color: cs.error)),
                  subtitle: const Text('Wipes recovery words (keeps your data)'),
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
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
