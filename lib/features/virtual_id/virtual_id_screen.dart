import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/models/document_model.dart';
import '../../core/providers/document_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/vault_image.dart';

/// A dark, wallet-card style presentation of an identity document — for
/// showing on-screen without handing over the phone or the physical card.
class VirtualIdScreen extends ConsumerWidget {
  final String documentId;

  const VirtualIdScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(documentsProvider.select(
      (docs) => docs.where((d) => d.id == documentId).firstOrNull,
    ));

    if (doc == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceInverse,
        body: Center(child: Text('Document not found')),
      );
    }

    final primaryFields = doc.extractedFields
        .where((f) => f.semanticKey != FactKeys.address)
        .take(6)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceInverse,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceInverse,
        foregroundColor: AppColors.textOnInverse,
        title: Text(
          'Digital ID',
          style: AppTextStyles.headline.copyWith(
            color: AppColors.textOnInverse,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: FadeSlideIn(
              child: Column(
                children: [
                  _IdCard(document: doc, fields: primaryFields),
                  const Gap(28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.textOnInverseMuted,
                      ),
                      const Gap(6),
                      Text(
                        'For display only — not a substitute for the physical document.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textOnInverseMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  final DocumentModel document;
  final List<ExtractedField> fields;

  const _IdCard({required this.document, required this.fields});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceInverseRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  document.displayTitle,
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.textOnInverse,
                  ),
                ),
              ),
              Icon(
                Icons.verified_rounded,
                size: 18,
                color: AppColors.accent.withValues(alpha: 0.9),
              ),
            ],
          ),
          const Gap(4),
          Text(
            document.ownerName,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textOnInverseMuted,
            ),
          ),
          const Gap(18),
          if (document.thumbFile.isNotEmpty || document.imageFile.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: VaultImage(
                fileName: document.imageFile.isNotEmpty
                    ? document.imageFile
                    : document.thumbFile,
                height: 150,
                width: double.infinity,
              ),
            ),
          const Gap(18),
          for (final field in fields) _IdFieldRow(field: field),
        ],
      ),
    );
  }
}

class _IdFieldRow extends StatelessWidget {
  final ExtractedField field;

  const _IdFieldRow({required this.field});

  bool get _isSensitive => FactKeys.sensitive.contains(field.semanticKey);

  @override
  Widget build(BuildContext context) {
    return _RevealableField(field: field, isSensitive: _isSensitive);
  }
}

class _RevealableField extends StatefulWidget {
  final ExtractedField field;
  final bool isSensitive;

  const _RevealableField({required this.field, required this.isSensitive});

  @override
  State<_RevealableField> createState() => _RevealableFieldState();
}

class _RevealableFieldState extends State<_RevealableField> {
  bool _revealed = false;

  String get _displayValue {
    if (!widget.isSensitive || _revealed) return widget.field.value;
    final value = widget.field.value;
    if (value.length <= 4) return '••••';
    return '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: GestureDetector(
        onTap: widget.isSensitive
            ? () {
                HapticFeedback.selectionClick();
                setState(() => _revealed = !_revealed);
              }
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.field.label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textOnInverseMuted,
                ),
              ),
            ),
            Text(
              _displayValue,
              style: AppTextStyles.mono.copyWith(
                color: AppColors.textOnInverse,
                fontSize: 14,
              ),
            ),
            if (widget.isSensitive) ...[
              const Gap(6),
              Icon(
                _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 14,
                color: AppColors.textOnInverseMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
