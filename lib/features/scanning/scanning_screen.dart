import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/capture_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';
import '../../shared/widgets/app_buttons.dart';

/// Runs the analysis pipeline with a calm, staged progress view, then hands
/// off to the review screen.
class ScanningScreen extends ConsumerStatefulWidget {
  final String? imagePath;

  const ScanningScreen({super.key, this.imagePath});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final path = widget.imagePath;
      if (path != null) {
        ref.read(captureProvider.notifier).process(path);
      } else {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureProvider);

    ref.listen<CaptureState>(captureProvider, (previous, next) {
      if (next.stage == CaptureStage.ready) {
        context.pushReplacement('/review');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: state.stage == CaptureStage.failed
              ? _FailedView(
                  message: state.error ?? 'Something went wrong.',
                  onRetry: () {
                    final path = widget.imagePath;
                    if (path != null) {
                      ref.read(captureProvider.notifier).process(path);
                    }
                  },
                  onCancel: () {
                    ref.read(captureProvider.notifier).reset();
                    context.go('/');
                  },
                )
              : _ProgressView(
                  imagePath: widget.imagePath,
                  stage: state.stage,
                ),
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  final String? imagePath;
  final CaptureStage stage;

  const _ProgressView({required this.imagePath, required this.stage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        if (imagePath != null)
          _ScanPreview(imagePath: imagePath!)
        else
          const SizedBox(height: 220),
        const Gap(40),
        Text('Reading your document', style: AppTextStyles.title),
        const Gap(6),
        Text(
          AppConfig.aiEnabled
              ? 'Gemini is reading the details'
              : 'Extracting details on-device',
          style: AppTextStyles.bodySecondary,
        ),
        const Gap(32),
        _StageStep(
          label: 'Scanning text',
          state: _stepState(CaptureStage.reading),
        ),
        _StageStep(
          label: 'Understanding the document',
          state: _stepState(CaptureStage.understanding),
        ),
        _StageStep(
          label: 'Organizing what it learned',
          state: _stepState(CaptureStage.organizing),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  _StepState _stepState(CaptureStage step) {
    final order = [
      CaptureStage.reading,
      CaptureStage.understanding,
      CaptureStage.organizing,
    ];
    final current = order.indexOf(stage);
    final target = order.indexOf(step);
    if (current < 0) return _StepState.done; // ready/saving already past
    if (target < current) return _StepState.done;
    if (target == current) return _StepState.active;
    return _StepState.pending;
  }
}

class _ScanPreview extends StatefulWidget {
  final String imagePath;

  const _ScanPreview({required this.imagePath});

  @override
  State<_ScanPreview> createState() => _ScanPreviewState();
}

class _ScanPreviewState extends State<_ScanPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(widget.imagePath), fit: BoxFit.cover),
            // Sweeping scan line.
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(0, _controller.value * 2 - 1),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0),
                          AppColors.accent.withValues(alpha: 0.22),
                          AppColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { pending, active, done }

class _StageStep extends StatelessWidget {
  final String label;
  final _StepState state;

  const _StageStep({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.ease,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: state == _StepState.active
            ? AppColors.surface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state == _StepState.active
              ? AppColors.border
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: switch (state) {
              _StepState.done => const Icon(
                Icons.check_circle_rounded,
                key: ValueKey('done'),
                color: AppColors.success,
                size: 20,
              ),
              _StepState.active => const SizedBox(
                key: ValueKey('active'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              _StepState.pending => Container(
                key: const ValueKey('pending'),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderStrong, width: 2),
                ),
              ),
            },
          ),
          const Gap(12),
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: state == _StepState.pending
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
              fontWeight: state == _StepState.active
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _FailedView({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.errorWash,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 32,
          ),
        ),
        const Gap(20),
        Text('Couldn\'t read that', style: AppTextStyles.titleSmall),
        const Gap(8),
        Text(
          message,
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const Gap(28),
        PrimaryButton(label: 'Try again', onPressed: onRetry),
        const Gap(10),
        SecondaryButton(label: 'Cancel', onPressed: onCancel),
      ],
    );
  }
}
