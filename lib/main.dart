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

class GlassApp extends ConsumerWidget {
  const GlassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsProvider).themeMode;
    return MaterialApp.router(
      title: 'WeatherGlass',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // On wide screens keep the single-column app centered at a comfortable
      // reading width rather than stretching edge-to-edge (phones pass through).
      builder: (context, child) {
        final inner = child ?? const SizedBox.shrink();
        if (MediaQuery.of(context).size.width <= 760) return inner;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(child: SizedBox(width: 760, child: inner)),
        );
      },
    );
  }
}
