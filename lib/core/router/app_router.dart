// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:glass/features/settings/presentation/privacy_screen.dart';
import 'package:glass/features/settings/presentation/settings_screen.dart';
import 'package:glass/features/weather/presentation/home_screen.dart';
import 'package:glass/features/weather/presentation/locations_screen.dart';

part 'app_router.g.dart';

CustomTransitionPage<T> _fade<T>({required LocalKey key, required Widget child}) =>
    CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, a, __, c) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: c,
      ),
    );

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
          path: '/',
          pageBuilder: (c, s) =>
              _fade(key: s.pageKey, child: const HomeScreen())),
      GoRoute(
          path: '/places',
          pageBuilder: (c, s) =>
              _fade(key: s.pageKey, child: const LocationsScreen())),
      GoRoute(
          path: '/privacy',
          pageBuilder: (c, s) =>
              _fade(key: s.pageKey, child: const PrivacyScreen())),
      GoRoute(
          path: '/settings',
          pageBuilder: (c, s) =>
              _fade(key: s.pageKey, child: const SettingsScreen())),
    ],
  );
}
