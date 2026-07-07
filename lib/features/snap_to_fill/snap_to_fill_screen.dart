import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/person_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/form_fill_service.dart';
import '../../core/services/image_prep.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';

enum _Stage { pickImage, analyzing, review, failed }

/// Photograph any blank form, let the vault detect its fields, and fill
/// them in from verified profile facts — reviewable before anything is
/// shared or saved.
class SnapToFillScreen extends ConsumerStatefulWidget {
  const SnapToFillScreen({super.key});

  @override
  ConsumerState<SnapToFillScreen> createState() => _SnapToFillScreenState();
}

class _SnapToFillScreenState extends ConsumerState<SnapToFillScreen> {
  _Stage _stage = _Stage.pickImage;
  String? _imagePath;
  FormAnalysis? _analysis;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    ref.read(appLockProvider.notifier).suppressAutoLock();
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
      );
      if (picked == null) return;
      setState(() {
        _imagePath = picked.path;
        _stage = _Stage.analyzing;
      });
      await _analyze(picked.path);
    } catch (_) {
      setState(() {
        _stage = _Stage.failed;
        _error = 'Could not open the camera or gallery.';
      });
    } finally {
      ref.read(appLockProvider.notifier).resumeAutoLock();
    }
  }

  Future<void> _analyze(String path) async {
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final ocr = await ocrService.processImage(path);
      final bytes = await ImagePrep.prepareForUpload(path);
      final decoded = await decodeImageDimensions(bytes);
      final facts = await ref.read(userFactsProvider.future);

      final analysis = await ref.read(formFillServiceProvider).analyzeForm(
        imageBytes: bytes,
        ocr: ocr,
        facts: facts,
        imageSize: decoded,
      );

      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _stage = _Stage.review;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = 'Could not read this form. Try a clearer, flatter photo.';
      });
    }
  }

  Future<ui.Size> decodeImageDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
  }

  void _reset() {
    setState(() {
      _stage = _Stage.pickImage;
      _imagePath = null;
      _analysis = null;
      _error = null;
    });
  }

  Future<void> _shareImage() async {
    final path = _imagePath;
    if (path == null) return;
    ref.read(appLockProvider.notifier).suppressAutoLock();
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Filled with AI Form & Vault'),
      );
    } finally {
      ref.read(appLockProvider.notifier).resumeAutoLock();
    }
  }

  void _editField(int index) {
    final analysis = _analysis;
    if (analysis == null) return;
    final field = analysis.fields[index];
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
            ),
            const Gap(16),
            PrimaryButton(
              label: 'Update',
              onPressed: () {
                setState(() {
                  final fields = [...analysis.fields];
                  fields[index] = fields[index].copyWith(
                    value: controller.text,
                    confidence: 1.0,
                  );
                  _analysis = FormAnalysis(
                    fields: fields,
                    imageSize: analysis.imageSize,
                    source: analysis.source,
                  );
                });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snap to Fill'),
        actions: [
          if (_stage == _Stage.review || _stage == _Stage.failed)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.pickImage => _PickView(onPick: _pick),
          _Stage.analyzing => const _AnalyzingView(),
          _Stage.review => _ReviewView(
            imagePath: _imagePath!,
            analysis: _analysis!,
            onEditField: _editField,
            onShare: _shareImage,
          ),
          _Stage.failed => _FailedView(
            message: _error ?? 'Something went wrong.',
            onRetry: _reset,
          ),
        },
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  final void Function(ImageSource) onPick;

  const _PickView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            index: 0,
            child: Text(
              'Photograph any blank form. The vault finds what it\'s asking '
              'for and fills it from your verified details.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
          const Gap(24),
          FadeSlideIn(
            index: 1,
            child: _OptionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              accent: true,
              onTap: () => onPick(ImageSource.camera),
            ),
          ),
          const Gap(12),
          FadeSlideIn(
            index: 2,
            child: _OptionCard(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              onTap: () => onPick(ImageSource.gallery),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool accent;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent ? AppColors.accent : AppColors.bgSunken,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: accent ? AppColors.textOnAccent : AppColors.textPrimary,
              size: 22,
            ),
          ),
          const Gap(14),
          Expanded(child: Text(title, style: AppTextStyles.headline)),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const Gap(20),
          Text('Reading the form', style: AppTextStyles.titleSmall),
          const Gap(6),
          Text(
            'Matching fields to your saved details',
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  final String imagePath;
  final FormAnalysis analysis;
  final void Function(int) onEditField;
  final VoidCallback onShare;

  const _ReviewView({
    required this.imagePath,
    required this.analysis,
    required this.onEditField,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final matched = analysis.matchedCount;
    final total = analysis.fields.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              FadeSlideIn(
                index: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(imagePath), fit: BoxFit.contain),
                ),
              ),
              const Gap(16),
              FadeSlideIn(
                index: 1,
                child: Row(
                  children: [
                    Icon(
                      matched == total
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: matched == total
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const Gap(8),
                    Text(
                      total == 0
                          ? 'No fillable fields detected'
                          : '$matched of $total fields filled from your vault',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
              const Gap(14),
              if (total == 0)
                EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No fields found',
                  message: 'Try a clearer photo with the whole form in view.',
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < analysis.fields.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        FadeSlideIn(
                          index: 2 + i,
                          child: _FillFieldRow(
                            field: analysis.fields[i],
                            onTap: () => onEditField(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(
              label: 'Share filled form',
              icon: Icons.ios_share_rounded,
              onPressed: total == 0 ? null : onShare,
            ),
          ),
        ),
      ],
    );
  }
}

class _FillFieldRow extends StatelessWidget {
  final FormFillField field;
  final VoidCallback onTap;

  const _FillFieldRow({required this.field, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
                field.matched ? field.value : 'Not in vault — tap to add',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14.5,
                  color: field.matched
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontStyle: field.matched
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(8),
            Icon(
              field.matched
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 16,
              color: field.matched
                  ? AppColors.success
                  : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailedView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const Gap(18),
            Text(
              message,
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const Gap(20),
            PrimaryButton(
              label: 'Try again',
              expanded: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
