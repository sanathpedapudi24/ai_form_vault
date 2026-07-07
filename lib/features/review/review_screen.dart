import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/document_model.dart';
import '../../core/providers/capture_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/section_header.dart';
import '../dashboard/widgets/category_visual.dart';

/// The one screen where the AI's read of a document is surfaced honestly
/// and the user gets the final word before anything is saved.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final saved = await ref.read(captureProvider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);

    if (saved != null) {
      ref.read(captureProvider.notifier).reset();
      context.go('/vault');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${saved.displayTitle} saved to your vault')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  void _editField(int index, ExtractedField field) {
    final controller = TextEditingController(text: field.value);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: AppTextStyles.titleSmall),
            const Gap(14),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'Enter value'),
              onSubmitted: (v) {
                ref.read(captureProvider.notifier).updateDraftField(index, v);
                Navigator.pop(context);
              },
            ),
            const Gap(16),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                ref
                    .read(captureProvider.notifier)
                    .updateDraftField(index, controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editName(DocumentModel draft) {
    final controller = TextEditingController(text: draft.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document name', style: AppTextStyles.titleSmall),
            const Gap(14),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.body,
              onSubmitted: (v) {
                ref.read(captureProvider.notifier).updateDraftName(v);
                Navigator.pop(context);
              },
            ),
            const Gap(16),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                ref
                    .read(captureProvider.notifier)
                    .updateDraftName(controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickCategory(DocumentModel draft) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in DocumentCategory.values)
              ListTile(
                leading: CategoryVisual(category: category, size: 36),
                title: Text(category.label, style: AppTextStyles.body),
                trailing: draft.category == category
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.accent,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(captureProvider.notifier)
                      .updateDraftCategory(category);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureProvider);
    final draft = state.draft;

    if (draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          if (state.imageBytes != null)
            IconButton(
              icon: const Icon(Icons.fullscreen_rounded),
              onPressed: () => _showFullImage(context, state.imageBytes!),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            FadeSlideIn(
              index: 0,
              child: _SummaryCard(
                draft: draft,
                imageBytes: state.imageBytes,
                onEditName: () => _editName(draft),
                onEditCategory: () => _pickCategory(draft),
              ),
            ),
            const Gap(20),
            FadeSlideIn(
              index: 1,
              child: SectionHeader(
                title: 'Extracted details',
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              ),
            ),
            if (draft.extractedFields.isEmpty)
              FadeSlideIn(
                index: 2,
                child: AppCard(
                  child: Text(
                    'No fields were confidently detected. You can add them '
                    'manually from the document later.',
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < draft.extractedFields.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      FadeSlideIn(
                        index: 2 + i,
                        child: _FieldRow(
                          field: draft.extractedFields[i],
                          onTap: () =>
                              _editField(i, draft.extractedFields[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: PrimaryButton(
            label: 'Save to vault',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(child: Image.memory(imageBytes)),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DocumentModel draft;
  final dynamic imageBytes;
  final VoidCallback onEditName;
  final VoidCallback onEditCategory;

  const _SummaryCard({
    required this.draft,
    required this.imageBytes,
    required this.onEditName,
    required this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    imageBytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              else
                CategoryVisual(category: draft.category, size: 56),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onEditName,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              draft.name,
                              style: AppTextStyles.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(4),
                          const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                    const Gap(4),
                    GestureDetector(
                      onTap: onEditCategory,
                      child: Row(
                        children: [
                          TagChip(
                            label: draft.category.label,
                            color: CategoryVisual.colorOf(draft.category),
                          ),
                          const Gap(6),
                          ConfidenceBadge(confidence: draft.confidence),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (draft.summary.isNotEmpty) ...[
            const Gap(14),
            const Divider(height: 1),
            const Gap(14),
            Text(draft.summary, style: AppTextStyles.bodySecondary),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final ExtractedField field;
  final VoidCallback onTap;

  const _FieldRow({required this.field, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            if (field.verified)
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.success,
              )
            else
              ConfidenceBadge(confidence: field.confidence, compact: true),
          ],
        ),
      ),
    );
  }
}
