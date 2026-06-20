import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/document_model.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/recent_document_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final documents = ref.watch(documentProvider);

    final recentDocs = documents.take(5).toList();
    final displayName = profile.name.isNotEmpty ? profile.name : 'Fida';

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, displayName),
              const Gap(24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSectionTitle('Add Document'),
              ),
              const Gap(14),
              _buildAddDocumentCards(context),
              const Gap(28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('Recent Documents'),
                    GestureDetector(
                      onTap: () => context.go('/vault'),
                      child: Text(
                        'See All',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(14),
              if (recentDocs.isNotEmpty)
                _buildRecentDocumentsList(context, recentDocs)
              else
                _buildEmptyState(),
              const Gap(100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning!';
    } else if (hour < 17) {
      greeting = 'Good afternoon!';
    } else {
      greeting = 'Good evening!';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(color: AppColors.bgPrimary),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hi, $userName 👋',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.bgPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              greeting,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAddDocumentCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _AddCard(
              icon: Icons.document_scanner_rounded,
              label: 'Scan Document',
              color: AppColors.accent,
              onTap: () => context.push('/capture'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _AddCard(
              icon: Icons.cloud_upload_outlined,
              label: 'Upload Document',
              color: AppColors.categoryEducation,
              onTap: () {
                ImagePicker().pickImage(source: ImageSource.gallery).then((
                  img,
                ) {
                  if (img != null && context.mounted) {
                    context.push('/scanning', extra: img.path);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDocumentsList(
    BuildContext context,
    List<DocumentModel> docs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: docs.map((doc) {
          final daysAgo = DateTime.now().difference(doc.uploadDate).inDays;
          final label = daysAgo == 0
              ? 'Today'
              : daysAgo == 1
              ? '1 day ago'
              : '$daysAgo days ago';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RecentDocumentTile(
              name: doc.name,
              subtitle: doc.type,
              fileType: doc.type,
              daysAgo: label,
              icon: _getCategoryIcon(doc.category),
              iconColor: _getCategoryColor(doc.category),
              confidence: doc.confidence,
              onTap: () => context.push('/extracted/${doc.id}'),
              onLongPress: () => context.push('/virtual-id/${doc.id}'),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No documents yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.identity:
        return Icons.badge_rounded;
      case DocumentCategory.education:
        return Icons.school_rounded;
      case DocumentCategory.finance:
        return Icons.account_balance_rounded;
      case DocumentCategory.medical:
        return Icons.medical_services_rounded;
      case DocumentCategory.travel:
        return Icons.flight_rounded;
      case DocumentCategory.family:
        return Icons.family_restroom_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color _getCategoryColor(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.identity:
        return AppColors.categoryIdentity;
      case DocumentCategory.education:
        return AppColors.categoryEducation;
      case DocumentCategory.finance:
        return AppColors.categoryFinance;
      case DocumentCategory.medical:
        return AppColors.categoryMedical;
      case DocumentCategory.travel:
        return AppColors.categoryTravel;
      case DocumentCategory.family:
        return AppColors.categoryFamily;
      default:
        return AppColors.categoryOther;
    }
  }
}

class _AddCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddCard({
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
