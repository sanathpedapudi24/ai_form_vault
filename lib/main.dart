import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/legacy_migration.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

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

    // MaterialApp.router below always builds BOTH ThemeDatas (for
    // themeMode switching), so AppColors.dark can't be a side effect of
    // AppTheme.light()/dark() — it has to be set once, here, to the actual
    // active mode, before any descendant widget reads AppColors.* directly.
    AppColors.dark = dark;

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
