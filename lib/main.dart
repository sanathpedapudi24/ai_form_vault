import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/legacy_migration.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // runZonedGuarded catches async errors Flutter's own handler misses and
  // forwards them to Crashlytics.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Route framework + async errors to Crashlytics.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Import documents saved by pre-database builds (no-op after first run).
      try {
        await const LegacyMigration().runIfNeeded();
      } catch (_) {
        // Never block startup on migration issues.
      }

      runApp(const ProviderScope(child: AIFormVaultApp()));
    },
    (error, stack) =>
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}

class AIFormVaultApp extends ConsumerWidget {
  const AIFormVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(settingsProvider.select((s) => s.darkMode));

    // Light is the current design focus. Dark uses the same M3 seed so the
    // palettes stay coherent while light-mode is polished first.
    final theme = dark ? AppTheme.dark() : AppTheme.light();

    final scheme = theme.colorScheme;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'AI Form & Vault',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
