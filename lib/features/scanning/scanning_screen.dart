import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/document_parser.dart';

class ScanningScreen extends ConsumerStatefulWidget {
  final String? imagePath;
  const ScanningScreen({super.key, this.imagePath});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen>
    with TickerProviderStateMixin {
  final OcrService _ocrService = OcrService();
  final DocumentParser _parser = DocumentParser();

  late final AnimationController _controller;
  late final List<Animation<double>> _itemAnimations;

  _ScanStage _stage = _ScanStage.ocr;
  String? _errorMessage;

  static const _itemCount = 4;
  static const _staggerDelay = 300;

  @override
  void initState() {
    super.initState();

    final totalDuration = Duration(
      milliseconds: _staggerDelay * _itemCount + 400,
    );
    _controller = AnimationController(vsync: this, duration: totalDuration);
    _itemAnimations = List.generate(_itemCount, (index) {
      final startFraction =
          (_staggerDelay * index) / totalDuration.inMilliseconds;
      final endFraction =
          (_staggerDelay * index + 400) / totalDuration.inMilliseconds;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(
          startFraction.clamp(0.0, 1.0),
          endFraction.clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      );
    });
    _controller.forward();

    _startProcessing();
  }

  Future<void> _startProcessing() async {
    final imagePath = widget.imagePath;
    if (imagePath == null) {
      setState(() => _errorMessage = 'No image provided');
      return;
    }

    try {
      final ocrResult = await _ocrService.processImage(imagePath);
      if (!mounted) return;

      setState(() => _stage = _ScanStage.parsing);

      final parseResult = _parser.parse(ocrResult.text);
      if (!mounted) return;

      setState(() => _stage = _ScanStage.done);

      final nameField = parseResult.fields
          .where((f) => f.label == 'Full Name')
          .firstOrNull;
      final personName = nameField?.value ?? '';
      final autoName = parseResult.detectedType.isNotEmpty
          ? '${parseResult.detectedType}_$personName'
          : personName.isNotEmpty
          ? personName
          : '${parseResult.documentType}_Document';

      final doc = await ref
          .read(documentProvider.notifier)
          .addDocument(
            name: autoName,
            ownerName: personName.isNotEmpty ? personName : 'User',
            category: parseResult.category,
            type: parseResult.documentType,
            detectedType: parseResult.detectedType,
            confidence: parseResult.overallConfidence,
            extractedFields: parseResult.fields,
            rawText: ocrResult.text,
            imagePath: imagePath,
          );

      final extractedName = nameField?.value ?? '';
      final extractedEmail = parseResult.fields
          .where((f) => f.label == 'Email')
          .firstOrNull
          ?.value;
      final extractedPhone = parseResult.fields
          .where((f) => f.label == 'Phone Number')
          .firstOrNull
          ?.value;
      ref
          .read(profileProvider.notifier)
          .autoFillFromDocument(
            name: extractedName,
            email: extractedEmail,
            phone: extractedPhone,
          );

      if (mounted) context.go('/extracted/${doc.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _ScanStage.error;
        _errorMessage = 'OCR failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Scanning Document',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _buildStatusBadge(),
                const SizedBox(height: 28),
                _buildDocumentCard(),
                const SizedBox(height: 32),
                _buildChecklist(),
                const SizedBox(height: 32),
                if (_stage == _ScanStage.error) _buildError(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final label = switch (_stage) {
      _ScanStage.ocr => 'AI is extracting text...',
      _ScanStage.parsing => 'Parsing document data...',
      _ScanStage.done => 'Processing complete',
      _ScanStage.error => 'Processing failed',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _stage == _ScanStage.error
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_stage != _ScanStage.done && _stage != _ScanStage.error)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          else if (_stage == _ScanStage.done)
            const Icon(Icons.check_circle, size: 16, color: AppColors.success)
          else
            const Icon(Icons.error, size: 16, color: AppColors.error),
          const Gap(8),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: _stage == _ScanStage.error
                  ? AppColors.error
                  : AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.bgTertiary, AppColors.cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.info.withValues(alpha: 0.3),
                  AppColors.info.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.person, color: AppColors.info, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _placeholderLine(width: 140),
                const SizedBox(height: 10),
                _placeholderLine(width: 100),
                const SizedBox(height: 10),
                _placeholderLine(width: 120),
                const SizedBox(height: 10),
                _placeholderLine(width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderLine({required double width}) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildChecklist() {
    final items = <_ChecklistItemData>[
      _ChecklistItemData(
        label: 'Reading text (OCR)',
        status: _stage.index >= _ScanStage.parsing.index
            ? _CheckStatus.done
            : _stage == _ScanStage.ocr
            ? _CheckStatus.inProgress
            : _CheckStatus.pending,
      ),
      _ChecklistItemData(
        label: 'Identifying fields',
        status: _stage.index >= _ScanStage.done.index
            ? _CheckStatus.done
            : _stage == _ScanStage.parsing
            ? _CheckStatus.inProgress
            : _CheckStatus.pending,
      ),
      _ChecklistItemData(
        label: 'Extracting key information',
        status: _stage == _ScanStage.done
            ? _CheckStatus.done
            : _CheckStatus.pending,
      ),
      _ChecklistItemData(
        label: 'Organizing data',
        status: _stage == _ScanStage.done
            ? _CheckStatus.done
            : _CheckStatus.pending,
      ),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(items.length, (index) {
              final opacity = _itemAnimations[index].value;
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - opacity)),
                  child: _buildChecklistItem(items[index]),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildChecklistItem(_ChecklistItemData item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.status == _CheckStatus.done
                  ? AppColors.success.withValues(alpha: 0.15)
                  : item.status == _CheckStatus.inProgress
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: item.status == _CheckStatus.pending
                  ? Border.all(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: item.status == _CheckStatus.done
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 16,
                  )
                : item.status == _CheckStatus.inProgress
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : const Icon(
                    Icons.circle_outlined,
                    color: AppColors.textTertiary,
                    size: 16,
                  ),
          ),
          const SizedBox(width: 14),
          Text(
            item.label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: item.status == _CheckStatus.pending
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
              fontWeight: item.status == _CheckStatus.inProgress
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const Gap(8),
          Text(
            _errorMessage ?? 'An error occurred',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const Gap(12),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

enum _ScanStage { ocr, parsing, done, error }

enum _CheckStatus { done, inProgress, pending }

class _ChecklistItemData {
  final String label;
  final _CheckStatus status;
  const _ChecklistItemData({required this.label, required this.status});
}
