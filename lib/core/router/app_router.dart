import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/scanning/scanning_screen.dart';
import '../../features/capture/document_capture_screen.dart';
import '../../features/extracted_info/extracted_info_screen.dart';
import '../../features/relationships/relationships_screen.dart';
import '../../features/snap_to_fill/snap_to_fill_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/virtual_id/virtual_id_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardScreen()),
            ),
          ],
        ),
        // Vault
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: VaultScreen()),
            ),
          ],
        ),
        // Search
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SearchScreen()),
            ),
          ],
        ),
        // Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen()),
            ),
          ],
        ),
      ],
    ),
    // Sub-routes (full screen, outside shell)
    GoRoute(
      path: '/capture',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentCaptureScreen(),
    ),
    GoRoute(
      path: '/scanning',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final imagePath = state.extra as String?;
        return ScanningScreen(imagePath: imagePath);
      },
    ),
    GoRoute(
      path: '/extracted/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final docId = state.pathParameters['id'] ?? '1';
        return ExtractedInfoScreen(documentId: docId);
      },
    ),
    GoRoute(
      path: '/virtual-id/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final docId = state.pathParameters['id'] ?? '1';
        return VirtualIdScreen(documentId: docId);
      },
    ),
    GoRoute(
      path: '/relationships',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RelationshipsScreen(),
    ),
    GoRoute(
      path: '/snap-to-fill',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SnapToFillScreen(),
    ),
    GoRoute(
      path: '/auth',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AuthScreen(),
    ),
  ],
);
