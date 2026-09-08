import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/snap_fill_provider.dart';
import '../../core/services/snap_fill_export.dart';
import '../../core/services/snap_fill_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';

/// Shows the fields Snap-to-Fill detected on the photographed form, each
/// pre-filled from the vault owner's saved facts where a match was found.
/// The user can edit any value, then export the answers drawn back onto the
/// original form photo(s) or copy them as plain text.
class SnapFillReviewScreen extends ConsumerStatefulWidget {
  const SnapFillReviewScreen({super.key});

  @override
  ConsumerState<SnapFillReviewScreen> createState() =>
      _SnapFillReviewScreenState();
}

class _SnapFillReviewScreenState extends ConsumerState<SnapFillReviewScreen> {
  final List<TextEditingController> _controllers = [];
  bool _exporting = false;

  void _syncControllers(List<DetectedFormField> fields) {
    while (_controllers.length < fields.length) {
      _controllers.add(TextEditingController());
    }
    for (var i = 0; i < fields.length; i++) {
      final value = fields[i].suggestedValue;
      if (_controllers[i].text != value) _controllers[i].text = value;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _copyAll(List<DetectedFormField> fields) async {
    final lines = [
      for (var i = 0; i < fields.length; i++)
        '${fields[i].label}: ${_controllers[i].text}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied filled answers to clipboard')),
    );
  }

  Future<void> _exportFilled(SnapFillState state) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ref.read(appLockProvider.notifier).suppressAutoLock();
    try {
      final files = await SnapFillExportService.exportFilledPages(
        state.imagePaths,
        state.fields,
      );
      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matched fields to place on the form yet.'),
          ),
        );
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [for (final f in files) XFile(f.path, mimeType: 'image/jpeg')],
          text: 'Filled form',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't export the filled form.")),
        );
      }
    } finally {
      ref.read(appLockProvider.notifier).resumeAutoLock();
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(snapFillProvider);

    if (state.stage == SnapFillStage.scanning) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.stage == SnapFillStage.error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review & fill')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Couldn't read that form. Try again with a clearer photo.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ),
      );
    }

    final fields = state.fields;
    _syncControllers(fields);

    if (fields.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review & fill')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "We couldn't find any blank fields on that form.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review & fill')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${state.matchedCount} of ${fields.length} fields matched '
                      'from your profile — check the rest.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: fields.length,
                separatorBuilder: (_, _) => const Gap(10),
                itemBuilder: (context, i) {
                  final field = fields[i];
                  return AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(field.label, style: AppTextStyles.label),
                            ),
                            if (!field.matched)
                              Text(
                                'No match',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        const Gap(6),
                        TextField(
                          controller: _controllers[i],
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Type the answer',
                          ),
                          onChanged: (v) => ref
                              .read(snapFillProvider.notifier)
                              .updateValue(i, v),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Export filled form',
                    icon: Icons.save_alt_outlined,
                    loading: _exporting,
                    onPressed: () => _exportFilled(state),
                  ),
                  const Gap(10),
                  SecondaryButton(
                    label: 'Copy answers as text',
                    icon: Icons.copy_all_outlined,
                    onPressed: () => _copyAll(fields),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
