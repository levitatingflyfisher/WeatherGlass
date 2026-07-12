import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:share_plus/share_plus.dart';

/// WeatherGlass-native "Backup & Restore" settings section.
///
/// The package ships a ready-made [BackupSettingsSection], but it draws its
/// own `Divider` + "Encrypted Backup" header and bare `ListTile`s, which
/// clashes with WeatherGlass's `_Label` (uppercase caption) + `Card` +
/// `ListTile` convention used by every other settings section (see
/// "Privacy & data" in settings_screen.dart). This widget reproduces the
/// same tile set with WeatherGlass's own presentation, delegating every bit
/// of state/crypto logic to [backupControllerProvider] and reusing the
/// package's [SeedPhraseModal] / [PhraseEntryDialog] — no auth/crypto state
/// machine is reinvented (SANCTUARY-BRIEF §4.W2).
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
                  onTap: () => _generatePhrase(context, ref),
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
                  onTap: () => _confirmPhraseReEntry(context, ref),
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
                  onTap: () => _exportBackup(context, ref),
                ),

              // Restore (always available).
              ListTile(
                leading: Icon(LucideIcons.download, color: cs.primary),
                title: const Text('Restore from backup'),
                subtitle: const Text(
                    'Load places and settings from an .ohbk file'),
                enabled: !isLoading,
                onTap: () => _restoreBackup(context, ref, hasKey),
              ),

              // Reset identity (danger zone, only if key exists).
              if (hasKey)
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: cs.error),
                  title: Text('Reset identity', style: TextStyle(color: cs.error)),
                  subtitle: const Text('Wipes recovery words (keeps your data)'),
                  enabled: !isLoading,
                  onTap: () => _resetIdentity(context, ref),
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

  Future<void> _generatePhrase(BuildContext context, WidgetRef ref) async {
    final phrase =
        await ref.read(backupControllerProvider.notifier).generateSeedPhrase();
    if (phrase == null || !context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // The recovery words must be acknowledged via the button, not
      // barrier-dismissed or swiped away.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => SeedPhraseModal(
        phrase: phrase,
        onAcknowledged: () {},
      ),
    );

    if (!context.mounted) return;
    await _confirmPhraseReEntry(context, ref);
  }

  Future<void> _confirmPhraseReEntry(
      BuildContext context, WidgetRef ref) async {
    while (context.mounted) {
      final reEntry = await PhraseEntryDialog.show(
        context,
        title: 'Re-enter your recovery words',
        body: 'Type the 12 words you just wrote down. This proves your '
            'paper copy is correct — without it, a typo could cost you all '
            'your data later.',
        confirmLabel: 'Confirm',
      );
      if (reEntry == null || !context.mounted) return;

      final ok = await ref
          .read(backupControllerProvider.notifier)
          .confirmSeedAcknowledged(reEntry);
      if (!context.mounted) return;
      if (ok) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Words didn't match. Check your paper copy and try again."),
        ),
      );
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(backupControllerProvider.notifier).exportBackup();
    if (result == null || !context.mounted) return;

    // Bytes-only share so the web build stays clean (no dart:io File).
    await Share.shareXFiles([
      XFile.fromData(result.bytes,
          mimeType: 'application/octet-stream', name: result.filename),
    ]);
  }

  Future<void> _restoreBackup(
      BuildContext context, WidgetRef ref, bool hasKey) async {
    // 1. Pick the .ohbk file — withData so we get bytes on every platform
    //    (no dart:io path handling, web-safe).
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.first.bytes == null) {
      return;
    }
    final blob = picked.files.first.bytes!;

    if (!context.mounted) return;

    final notifier = ref.read(backupControllerProvider.notifier);
    final config = ref.read(sanctuaryBackupConfigProvider);

    // 2. If the user already has a key we use it; otherwise prompt for
    //    phrase.
    RestoreOutcome outcome;
    if (hasKey) {
      final confirm = await _confirmDestructive(context, config);
      if (!confirm || !context.mounted) return;
      outcome = await notifier.restoreFromBlob(blob);

      // This device's key didn't unlock the backup (it was made under a
      // different phrase) — offer to enter the words it was created with.
      if (outcome == RestoreOutcome.wrongPhrase && context.mounted) {
        final phrase = await PhraseEntryDialog.show(
          context,
          title: "Enter the backup's recovery words",
          body: 'This backup was made with a different set of words than '
              'this device has. Enter the 12 words from when it was created.',
        );
        if (phrase == null || !context.mounted) return;
        outcome = await notifier.restoreWithPhrase(blob, phrase);
      }
    } else {
      final phrase = await PhraseEntryDialog.show(context);
      if (phrase == null || !context.mounted) return;
      final confirm = await _confirmDestructive(context, config);
      if (!confirm || !context.mounted) return;
      outcome = await notifier.restoreWithPhrase(blob, phrase);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_restoreMessage(outcome, config))),
    );
  }

  String _restoreMessage(RestoreOutcome outcome, SanctuaryBackupConfig config) =>
      switch (outcome) {
        RestoreOutcome.success => 'Places and settings restored.',
        RestoreOutcome.wrongPhrase =>
          "Those words didn't unlock this backup. Try the words from when it "
              'was made.',
        RestoreOutcome.corruptFile =>
          "This file looks damaged or isn't a ${config.appDisplayName} backup.",
        RestoreOutcome.tooNewBackup =>
          'This backup was made by a newer version of ${config.appDisplayName}. '
              'Update the app, then restore.',
        RestoreOutcome.noKey =>
          'Set up encrypted backup first, or enter your recovery words.',
        RestoreOutcome.failed => 'Restore failed. Please try again.',
      };

  Future<void> _resetIdentity(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset identity?'),
        content: const Text(
          'This will erase your recovery words from this device. Your data '
          "will NOT be deleted, but you won't be able to make encrypted "
          'backups until you set up a new phrase.\n\n'
          'Any existing backup files will only be recoverable with the old '
          'recovery words.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(backupControllerProvider.notifier).resetIdentity();
    }
  }

  Future<bool> _confirmDestructive(
      BuildContext context, SanctuaryBackupConfig config) async {
    // States the destructive-replace consequence plainly (SANCTUARY-BRIEF
    // §2.5). WeatherGlass supplies the specific sentence via
    // [SanctuaryBackupConfig.restoreReplaceConsequence] (glassBackupConfig).
    final consequence = config.restoreReplaceConsequence ??
        'Restoring will permanently delete all current '
            '${config.appDisplayName} data on this device and replace it with '
            'the contents of the backup file.';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Replace all data?'),
        content: Text('$consequence\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
