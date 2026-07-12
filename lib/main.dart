import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/legacy_migration.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/lock/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
}

class AIFormVaultApp extends ConsumerWidget {
  const AIFormVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(settingsProvider.select((s) => s.darkMode));

    // Build the theme first — this sets AppColors.dark — then style the
    // system bars to match. Watching darkMode rebuilds the whole tree, so
    // every AppColors getter re-resolves to the new palette.
    final theme = dark ? AppTheme.dark() : AppTheme.light();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppColors.bg,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'AI Form & Vault',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: appRouter,
      builder: (context, child) => AppLockGate(child: child),
    );
  }
}
