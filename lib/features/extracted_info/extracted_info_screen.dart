import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/models/document_model.dart';
import '../../core/providers/document_provider.dart';
import '../../shared/widgets/glass_card.dart';

class ExtractedInfoScreen extends ConsumerWidget {
  final String documentId;
  const ExtractedInfoScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentProvider);
    final doc = docs.where((d) => d.id == documentId).firstOrNull;
    if (doc == null) {
      return Scaffold(
        backgroundColor: AppColors.bgSecondary,
        body: const Center(child: Text('Document not found')),
      );
    }

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: AppColors.bgSecondary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Text(
            doc.detectedType.isNotEmpty ? doc.detectedType : doc.name,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              onSelected: (value) async {
                switch (value) {
                  case 'digital_id':
                    context.push('/virtual-id/$documentId');
                  case 'delete':
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Delete Document'),
                        content: const Text(
                          'Are you sure? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      ref
                          .read(documentProvider.notifier)
                          .deleteDocument(documentId);
                      if (context.mounted) context.pop();
                    }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'digital_id',
                  child: ListTile(
                    leading: Icon(Icons.credit_card, color: AppColors.accent),
                    title: Text('View Digital ID'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorPadding: const EdgeInsets.all(3),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textTertiary,
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: AppTextStyles.labelMedium,
                tabs: const [
                  Tab(text: 'Fields'),
                  Tab(text: 'Raw Text'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _FieldsTab(doc: doc),
            _RawTextTab(doc: doc),
          ],
        ),
      ),
    );
  }
}

class _FieldsTab extends ConsumerStatefulWidget {
  final DocumentModel doc;
  const _FieldsTab({required this.doc});

  @override
  ConsumerState<_FieldsTab> createState() => _FieldsTabState();
}

class _FieldsTabState extends ConsumerState<_FieldsTab> {
  late List<_FieldState> _fieldStates;

  @override
  void initState() {
    super.initState();
    _fieldStates = widget.doc.extractedFields
        .map(
          (f) => _FieldState(
            label: f.label,
            value: f.value,
            confidence: f.confidence,
            sourceDocument: f.sourceDocument,
          ),
        )
        .toList();
  }

  void _confirmField(int index) {
    setState(() {
      _fieldStates[index].confidence = 1.0;
    });
    _saveToProvider();
  }

  void _editField(int index) {
    final field = _fieldStates[index];
    final controller = TextEditingController(text: field.value);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit ${field.label}',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: field.label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.bgSecondary,
              ),
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _fieldStates[index].value = controller.text.trim();
                    _fieldStates[index].confidence = 1.0;
                  });
                  _saveToProvider();
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveToProvider() {
    final fields = _fieldStates
        .map(
          (s) => ExtractedField(
            label: s.label,
            value: s.value,
            confidence: s.confidence,
            sourceDocument: s.sourceDocument,
          ),
        )
        .toList();
    final updated = widget.doc.copyWith(extractedFields: fields);
    ref.read(documentProvider.notifier).updateDocument(updated);
  }

  bool get _hasUnconfirmed => _fieldStates.any((s) => s.confidence < 0.8);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.doc.imagePath.isNotEmpty &&
                    File(widget.doc.imagePath).existsSync())
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(widget.doc.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  ),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Extracted Information',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (_hasUnconfirmed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Review needed',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._fieldStates.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final field = entry.value;
                        final needsReview = field.confidence < 0.8;
                        return _FieldRowWithActions(
                          label: field.label,
                          value: field.value,
                          confidence: field.confidence,
                          needsReview: needsReview,
                          onEdit: () => _editField(idx),
                          onConfirm: needsReview
                              ? () => _confirmField(idx)
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldState {
  String label;
  String value;
  double confidence;
  String sourceDocument;

  _FieldState({
    required this.label,
    required this.value,
    required this.confidence,
    required this.sourceDocument,
  });
}

class _FieldRowWithActions extends StatelessWidget {
  final String label;
  final String value;
  final double confidence;
  final bool needsReview;
  final VoidCallback onEdit;
  final VoidCallback? onConfirm;

  const _FieldRowWithActions({
    required this.label,
    required this.value,
    required this.confidence,
    required this.needsReview,
    required this.onEdit,
    this.onConfirm,
  });

  Color _confidenceColor() {
    if (confidence >= 0.9) return AppColors.success;
    if (confidence >= 0.7) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _confidenceColor().withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(confidence * 100).toInt()}%',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _confidenceColor(),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (needsReview)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'low',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (needsReview) ...[
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  tooltip: 'Confirm',
                  onTap: onConfirm,
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  color: AppColors.accent,
                  tooltip: 'Edit',
                  onTap: onEdit,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _RawTextTab extends StatelessWidget {
  final DocumentModel doc;
  const _RawTextTab({required this.doc});

  String _displayText() {
    if (doc.rawText.isNotEmpty) return doc.rawText;
    final buffer = StringBuffer();
    buffer.writeln('─── RAW OCR OUTPUT ───');
    buffer.writeln();
    for (final field in doc.extractedFields) {
      buffer.writeln('${field.label}: ${field.value}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgTertiary, AppColors.cardBg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: SelectableText(
          _displayText(),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontFamily: 'monospace',
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
