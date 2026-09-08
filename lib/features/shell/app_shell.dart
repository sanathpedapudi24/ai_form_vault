import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../core/providers/person_provider.dart';

/// App scaffold with a standard Material 3 [NavigationBar] and a scan
/// [FloatingActionButton], matching the platform-native MD3 look.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  void _onTab(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(
      identityGraphProvider.select((s) => s.pending.length),
    );
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _onTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(shadcn.LucideIcons.house),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(shadcn.LucideIcons.folderOpen),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: pendingCount > 0
                ? Badge(
                    label: Text(pendingCount > 9 ? '9+' : '$pendingCount'),
                    child: const Icon(shadcn.LucideIcons.users),
                  )
                : const Icon(shadcn.LucideIcons.users),
            label: 'People',
          ),
          const NavigationDestination(
            icon: Icon(shadcn.LucideIcons.user),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/capture');
        },
        child: const Icon(shadcn.LucideIcons.scanLine),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
