import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _onSwipe(DragEndDetails details) {
    const threshold = 50.0;
    final current = navigationShell.currentIndex;
    if (details.primaryVelocity! < -threshold && current < 3) {
      final next = current + 1;
      if (next != 2) _onTap(next);
    } else if (details.primaryVelocity! > threshold && current > 0) {
      final prev = current - 1;
      if (prev != 2) _onTap(prev);
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AddDocumentSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: GestureDetector(
        onHorizontalDragEnd: _onSwipe,
        child: navigationShell,
      ),
      bottomNavigationBar: _FloatingPillNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        onAddTap: () => _showAddSheet(context),
        showProfileRedDot: !profile.isComplete,
      ),
    );
  }
}

class _FloatingPillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;
  final bool showProfileRedDot;

  const _FloatingPillNav({
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
    this.showProfileRedDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = <_NavItemData>[
      _NavItemData(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItemData(Icons.lock_outline_rounded, Icons.lock_rounded, 'Vault'),
      _NavItemData(Icons.search_outlined, Icons.search_rounded, 'Search'),
      _NavItemData(Icons.person_outline, Icons.person_rounded, 'Profile'),
    ];

    return Container(
      height: 88,
      alignment: Alignment.topCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(5, (i) {
                if (i == 2) {
                  return _CenterAddButton(onTap: onAddTap);
                }
                final itemIndex = i > 2 ? i - 1 : i;
                final item = navItems[itemIndex];
                final isProfile = itemIndex == 3;
                return Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _NavItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        isSelected: currentIndex == itemIndex,
                        onTap: () => onTap(itemIndex),
                      ),
                      if (isProfile && showProfileRedDot)
                        Positioned(
                          top: 2,
                          right: 6,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData(this.icon, this.activeIcon, this.label);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppColors.navActive : AppColors.navInactive,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        transform: Matrix4.translationValues(0, -6, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _AddDocumentSheet extends StatelessWidget {
  const _AddDocumentSheet();

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null && context.mounted) {
      Navigator.of(context).pop();
      context.push('/scanning', extra: image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Document',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SheetOption(
                      icon: Icons.document_scanner_rounded,
                      label: 'Scan',
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/capture');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SheetOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Upload',
                      color: AppColors.categoryEducation,
                      onTap: () => _pickImage(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SheetOption(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Import PDF',
                      color: AppColors.categoryFinance,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/scanning');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SheetOption(
                      icon: Icons.link_rounded,
                      label: 'From Link',
                      color: AppColors.categoryFamily,
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
