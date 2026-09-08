import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/snap_fill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';

/// Entry point for Snap-to-Fill: photograph or import a blank paper form
/// (camera scan, gallery, or PDF — same import options as the vault capture
/// flow) and match its fields against the vault owner's saved facts.
class SnapFillCaptureScreen extends ConsumerStatefulWidget {
  const SnapFillCaptureScreen({super.key});

  @override
  ConsumerState<SnapFillCaptureScreen> createState() =>
      _SnapFillCaptureScreenState();
}

class _SnapFillCaptureScreenState
    extends ConsumerState<SnapFillCaptureScreen> {
  bool _busy = false;
  static const _maxPdfPages = 5;

  Future<void> _process(List<String> imagePaths) async {
    if (imagePaths.isEmpty || !mounted) return;
    await ref.read(snapFillProvider.notifier).process(imagePaths);
    if (mounted) context.push('/snap-fill/review');
  }

  Future<void> _run(Future<List<String>> Function() pick) async {
    if (_busy) return;
    setState(() => _busy = true);
    ref.read(appLockProvider.notifier).suppressAutoLock();
    try {
      final paths = await pick();
      await _process(paths);
    } catch (_) {
      _showError('Could not read that form. Try again.');
    } finally {
      ref.read(appLockProvider.notifier).resumeAutoLock();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>> _scanWithCamera() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.filter,
        pageLimit: _maxPdfPages,
        isGalleryImport: false,
      ),
    );
    final result = await scanner.scanDocument();
    return result.images ?? const [];
  }

  Future<List<String>> _pickFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
    return picked.map((x) => x.path).toList();
  }

  Future<List<String>> _importPdf() async {
    const pdfType = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );
    final picked = await openFile(acceptedTypeGroups: [pdfType]);
    final path = picked?.path;
    if (path == null) return const [];

    final pdf = await PdfDocument.openFile(path);
    final tempDir = await getTemporaryDirectory();
    final pagePaths = <String>[];
    final pageCount = pdf.pagesCount.clamp(0, _maxPdfPages);
    for (var i = 1; i <= pageCount; i++) {
      final page = await pdf.getPage(i);
      final rendered = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (rendered == null) continue;
      final file = File(
        p.join(
          tempDir.path,
          'snap_fill_pdf_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        ),
      );
      await file.writeAsBytes(rendered.bytes, flush: true);
      pagePaths.add(file.path);
    }
    await pdf.close();
    return pagePaths;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Snap to fill')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Photograph or import a blank form and we'll match its "
                'fields to your saved details.',
                style: AppTextStyles.bodySecondary,
              ),
              const Gap(24),
              _SnapOption(
                icon: Icons.document_scanner_outlined,
                title: 'Scan with camera',
                subtitle: 'Auto-detects edges, up to $_maxPdfPages pages',
                accent: true,
                busy: _busy,
                onTap: () => _run(_scanWithCamera),
              ),
              const Gap(12),
              _SnapOption(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle: 'Pick one or more photos you already have',
                busy: _busy,
                onTap: () => _run(_pickFromGallery),
              ),
              const Gap(12),
              _SnapOption(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Import a PDF',
                subtitle: 'First $_maxPdfPages pages are read like a scan',
                busy: _busy,
                onTap: () => _run(_importPdf),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final bool busy;
  final VoidCallback onTap;

  const _SnapOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent = false,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent
                  ? context.scheme.primary
                  : context.scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: accent
                  ? context.scheme.onPrimary
                  : context.scheme.onSurface,
              size: 24,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline),
                const Gap(3),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
