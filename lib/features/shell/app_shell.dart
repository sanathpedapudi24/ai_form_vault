import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../core/providers/person_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';

/// App scaffold with a Liquid-Glass floating bottom navigation bar.
///
/// A frosted, blurred pill bar inspired by iOS Liquid Glass: four
/// destinations with a springy sliding pill behind the active one, plus an
/// elevated scan FAB that "pops" above the bar at the center.
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
    final scheme = context.scheme;
    final index = navigationShell.currentIndex;

    // Glass surface: heavy blur + translucent fill, so content slides
    // beneath the bar and shows through as a frosted pane.
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sliding glass pill behind the active destination.
                    _SlidingIndicator(index: index),
                    Row(
                      children: [
                        _NavItem(
                          icon: shadcn.LucideIcons.house,
                          label: 'Home',
                          active: index == 0,
                          onTap: () => _onTab(0),
                        ),
                        _NavItem(
                          icon: shadcn.LucideIcons.folderOpen,
                          label: 'Vault',
                          active: index == 1,
                          onTap: () => _onTab(1),
                        ),
                        const SizedBox(width: 72), // reserved for the FAB
                        _NavItem(
                          icon: shadcn.LucideIcons.users,
                          label: 'People',
                          active: index == 2,
                          badgeCount: pendingCount,
                          onTap: () => _onTab(2),
                        ),
                        _NavItem(
                          icon: shadcn.LucideIcons.user,
                          label: 'Profile',
                          active: index == 3,
                          onTap: () => _onTab(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _ScanFab(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/capture');
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// A pill that slides between destinations. Positioned from the same slot
/// geometry as the nav Row (4 equal Expanded slots wrapping a fixed 72px
/// center block for the scan FAB), so it tracks the active item exactly.
class _SlidingIndicator extends StatelessWidget {
  final int index;

  const _SlidingIndicator({required this.index});

  static const double _fabslot = 72;
  static const double _pad = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = (constraints.maxWidth - _pad * 2 - _fabslot) / 4;
          final pillWidth = slotWidth * 0.72;

          // Center x of each slot.
          double center(int i) {
            if (i < 2) return _pad + slotWidth * (i + 0.5);
            return _pad + slotWidth * 2.5 + _fabslot + slotWidth * (i - 2);
          }

          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.base,
                curve: AppMotion.ease,
                left: center(index) - pillWidth / 2,
                top: (constraints.maxHeight - 52) / 2,
                width: pillWidth,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: active ? scheme.primary : AppColors.navInactive,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: scheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: scheme.onError,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? scheme.primary : AppColors.navInactive,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elevated scan button. It floats above the glass bar (via the FAB slot),
/// reads as the single prominent action, and is tinted with the brand seed.
class _ScanFab extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.85)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          shadcn.LucideIcons.scanLine,
          color: scheme.onPrimary,
          size: 28,
        ),
      ),
    );
  }
}