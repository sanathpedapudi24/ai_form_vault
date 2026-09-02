import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/document_capture_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/document/document_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/relationships/relationships_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/scanning/scanning_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/vault/vault_screen.dart';
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: VaultScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/people',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: RelationshipsScreen()),
            ),
          ],
        ),
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
    // Full-screen flows outside the shell.
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/capture',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentCaptureScreen(),
    ),
    GoRoute(
      path: '/scanning',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final paths = switch (state.extra) {
          final List<String> list => list,
          final String single => [single],
          _ => const <String>[],
        };
        return ScanningScreen(imagePaths: paths);
      },
    ),
    GoRoute(
      path: '/review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReviewScreen(),
    ),
    GoRoute(
      path: '/document/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final docId = state.pathParameters['id']!;
        return DocumentDetailScreen(documentId: docId);
      },
    ),
    GoRoute(
      path: '/virtual-id/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final docId = state.pathParameters['id']!;
        return VirtualIdScreen(documentId: docId);
      },
    ),
  ],
);
