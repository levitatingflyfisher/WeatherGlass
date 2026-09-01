// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glass/core/providers/core_providers.dart';
import 'package:glass/core/router/app_router.dart';
import 'package:glass/features/sanctuary_backup/backup_config.dart';
import 'package:glass/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:glass/features/settings/settings_controller.dart';
import 'package:glass/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Encrypted-backup wiring (sanctuary_backup_ui). WeatherGlass is a
        // new app, so it gets its own isolated key material (appDomain
        // 'weatherglass') and its own AEAD context — no legacy-compat
        // constraint like Lullaby's (SANCTUARY-BRIEF §2.1, §2.3, §4.W2).
        sanctuaryAppDomainProvider.overrideWithValue('weatherglass'),
        sanctuaryBackupConfigProvider.overrideWithValue(glassBackupConfig),
        // On web every fleet PWA shares one origin, so one localStorage:
        // without this the recovery words would be shared with sibling apps
        // (sanctuary_backup_ui 0.3.0). Does nothing on native.
        appScopedKeyStoreOverride(),
        backupSerializerProvider.overrideWith(
          (ref) => GlassBackupSerializer(
            ref.watch(appDatabaseProvider),
            ref.watch(sharedPreferencesProvider),
          ),
        ),
      ],
      child: const GlassApp(),
    ),
  );
}

class GlassApp extends ConsumerStatefulWidget {
  const GlassApp({super.key});

  @override
  ConsumerState<GlassApp> createState() => _GlassAppState();
}

class _GlassAppState extends ConsumerState<GlassApp> {
  @override
  void initState() {
    super.initState();
    // Silent backup freshness net (BACKUP_RETENTION_SPEC §3): if a key
    // exists and the newest vault snapshot is >7 days old, take one.
    // Post-frame + fire-and-forget — never blocks boot, never surfaces
    // errors (runStartupMaintenance swallows everything, incl. no-key).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupControllerProvider.notifier).runStartupMaintenance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsProvider).themeMode;
    return MaterialApp.router(
      title: 'WeatherGlass',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Wide screens: each screen caps its own content with OhPage, so the
      // app bars and Home's sky still reach the window edges (the old 760 px
      // box around the whole app drew a hard edge on the sky).
      routerConfig: router,
    );
  }
}
