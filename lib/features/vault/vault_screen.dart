import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/document_model.dart';
import '../../core/providers/document_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/vault_image.dart';
import '../dashboard/widgets/category_visual.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  DocumentCategory? _selected;

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsByCategoryProvider(_selected));
    final all = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'All',
                    count: all.length,
                    selected: _selected == null,
                    onTap: () => setState(() => _selected = null),
                  ),
                  for (final category in DocumentCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: category.label,
                        count: all
                            .where((d) => d.category == category)
                            .length,
                        selected: _selected == category,
                        color: CategoryVisual.colorOf(category),
                        onTap: () => setState(() => _selected = category),
                      ),
                    ),
                ],
              ),
            ),
            const Gap(8),
            Expanded(
              child: docs.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: _selected == null
                          ? 'Your vault is empty'
                          : 'No ${_selected!.label.toLowerCase()} documents',
                      message: 'Scan a document to get started.',
                      actionLabel: 'Scan document',
                      onAction: () => context.push('/capture'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      itemCount: docs.length,
                      itemBuilder: (context, index) => FadeSlideIn(
                        index: index,
                        offset: 10,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DocumentTile(document: docs[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.bgSunken,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const Gap(6),
              Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DocumentModel document;

  const _DocumentTile({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/document/${document.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          document.thumbFile.isNotEmpty
              ? VaultImage(fileName: document.thumbFile, width: 52, height: 52)
              : CategoryVisual(category: document.category, size: 52),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.displayTitle,
                  style: AppTextStyles.itemTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Row(
                  children: [
                    if (document.ownerName.isNotEmpty) ...[
                      Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const Gap(3),
                      Flexible(
                        child: Text(
                          document.ownerName,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap(8),
                    ],
                    Text(document.dateFormatted, style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          const Gap(8),
          ConfidenceBadge(confidence: document.confidence, compact: true),
        ],
      ),
    );
  }
}
