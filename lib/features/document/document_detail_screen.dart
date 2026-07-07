import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/document_model.dart';
import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/document_provider.dart';
import '../../core/services/image_vault.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/vault_image.dart';
import '../dashboard/widgets/category_visual.dart';

class DocumentDetailScreen extends ConsumerWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  Future<void> _share(WidgetRef ref, DocumentModel doc) async {
    final bytes = await ImageVault.instance.read(doc.imageFile);
    if (bytes == null) return;
    // The share sheet is a separate Activity — same re-lock hazard as the
    // camera/gallery picker.
    ref.read(appLockProvider.notifier).suppressAutoLock();
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/jpeg', name: '${doc.name}.jpg')],
          text: doc.displayTitle,
        ),
      );
    } finally {
      ref.read(appLockProvider.notifier).resumeAutoLock();
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DocumentModel doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          'This will permanently remove "${doc.displayTitle}" and its image '
          'from your vault. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(documentsProvider.notifier).remove(doc.id);
              if (context.mounted) context.pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentsProvider.select(
      (docs) => docs.where((d) => d.id == documentId).firstOrNull,
    ));

    if (doc == null) {
      return const Scaffold(body: Center(child: Text('Document not found')));
    }

    final categoryColor = CategoryVisual.colorOf(doc.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.displayTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (doc.category == DocumentCategory.identity)
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: 'View as Digital ID',
              onPressed: () => context.push('/virtual-id/${doc.id}'),
            ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _share(ref, doc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDelete(context, ref, doc),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FadeSlideIn(
              index: 0,
              child: Hero(
                tag: 'doc-image-${doc.id}',
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: doc.imageFile.isNotEmpty
                      ? VaultImage(
                          fileName: doc.imageFile,
                          borderRadius: BorderRadius.circular(20),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgSunken,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: CategoryVisual(category: doc.category, size: 64),
                          ),
                        ),
                ),
              ),
            ),
            const Gap(18),
            FadeSlideIn(
              index: 1,
              child: Row(
                children: [
                  TagChip(label: doc.category.label, color: categoryColor),
                  const Gap(8),
                  ConfidenceBadge(confidence: doc.confidence),
                  const Spacer(),
                  Text(doc.dateFormatted, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Gap(14),
            if (doc.ownerName.isNotEmpty)
              FadeSlideIn(
                index: 2,
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const Gap(6),
                    Text(doc.ownerName, style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
            if (doc.summary.isNotEmpty) ...[
              const Gap(14),
              FadeSlideIn(
                index: 3,
                child: Text(doc.summary, style: AppTextStyles.body),
              ),
            ],
            const Gap(24),
            FadeSlideIn(
              index: 4,
              child: const SectionHeader(
                title: 'Details',
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              ),
            ),
            if (doc.extractedFields.isEmpty)
              FadeSlideIn(
                index: 5,
                child: AppCard(
                  child: Text(
                    'No details were extracted from this document.',
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < doc.extractedFields.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      FadeSlideIn(
                        index: 5 + i,
                        child: _DetailFieldRow(field: doc.extractedFields[i]),
                      ),
                    ],
                  ],
                ),
              ),
            const Gap(20),
            FadeSlideIn(
              index: 6 + doc.extractedFields.length,
              child: SecondaryButton(
                label: 'Use in Snap-to-Fill',
                icon: Icons.edit_document,
                onPressed: () => context.push('/snap-to-fill'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailFieldRow extends StatelessWidget {
  final ExtractedField field;

  const _DetailFieldRow({required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(field.label, style: AppTextStyles.label),
          ),
          Expanded(
            flex: 3,
            child: Text(
              field.value,
              style: (FactKeys.sensitive.contains(field.semanticKey)
                      ? AppTextStyles.mono
                      : AppTextStyles.body)
                  .copyWith(fontSize: 14.5),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
