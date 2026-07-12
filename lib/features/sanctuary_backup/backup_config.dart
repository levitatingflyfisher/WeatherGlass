import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import '../../core/providers/core_providers.dart';
import '../settings/settings_controller.dart';

/// WeatherGlass's [SanctuaryBackupConfig] (SANCTUARY-BRIEF §4.W2).
///
/// Pulled out of `main.dart` — like Bulwark's `backup_config.dart` — so the
/// restore-consequence copy and the invalidation set are directly
/// unit-testable without bootstrapping the whole app widget tree.
const glassBackupConfig = SanctuaryBackupConfig(
  appId: 'weatherglass',
  aadContext: 'weatherglass-backup/v1',
  appDisplayName: 'WeatherGlass',
  restoreReplaceConsequence:
      'Restoring will delete all saved places and settings on this device, '
      'then replace them with the contents of the backup file. Cached '
      'forecasts are not part of the backup — WeatherGlass fetches them '
      'again automatically the next time you open a place.',
  onAfterRestore: afterGlassRestore,
);

/// Invalidates every provider that could still reference now-wiped rows or a
/// now-stale one-shot preference read after a destructive restore
/// (SANCTUARY-BRIEF §2.5; the saved-locations + settings pair is the
/// invalidation set named in SANCTUARY-BRIEF §4.W2 for WeatherGlass).
///
/// - [savedLocationsProvider] — a Drift watch stream, so it already
///   self-refreshes on the next DB write; invalidating it here is a
///   harmless, explicit belt.
/// - [settingsProvider] — load-bearing. It's a one-shot read of
///   [SharedPreferences] taken at provider build time, and restore writes
///   preferences directly (bypassing Riverpod, since prefs can't join the
///   Drift transaction — see [GlassBackupSerializer]). Without this
///   invalidation the restored units/precision/theme would silently not
///   take effect until some unrelated rebuild happened to re-run it.
/// - [selectedCityIdProvider] — the one lingering in-memory reference to a
///   specific place id (the cross-screen "jump to this city" request);
///   cleared so a request queued right before a restore can't animate Home
///   to a since-wiped id.
void afterGlassRestore(Ref ref) {
  ref.invalidate(savedLocationsProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(selectedCityIdProvider);
}
