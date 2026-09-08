import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fade_slide_in.dart';

/// Entry point for adding a document: ML Kit's edge-detecting scanner
/// (up to 5 pages), a gallery pick, or a PDF import — all hand JPEG page
/// paths to the same scanning pipeline.
class DocumentCaptureScreen extends ConsumerStatefulWidget {
  const DocumentCaptureScreen({super.key});

  @override
  ConsumerState<DocumentCaptureScreen> createState() =>
      _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends ConsumerState<DocumentCaptureScreen> {
  bool _busy = false;

  Future<void> _scanWithCamera() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: const {DocumentFormat.jpeg},
          mode: ScannerMode.filter,
          pageLimit: 5,
          isGalleryImport: false,
        ),
      );
      final result = await scanner.scanDocument();
      final images = result.images;
      if (images != null && images.isNotEmpty && mounted) {
        context.pushReplacement('/scanning', extra: List<String>.from(images));
      }
    } catch (_) {
      _showError('Could not open the scanner. Try the gallery instead.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Cap the decoded resolution here (native, memory-efficient downsample)
      // so a 48-200MP gallery photo never reaches the app at full size — an
      // undownscaled original blows the pure-Dart OCR/upload decode buffers
      // and gets the whole process OOM-killed by Android.
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
      );
      if (picked != null && mounted) {
        context.pushReplacement('/scanning', extra: <String>[picked.path]);
      }
    } catch (_) {
      _showError('Could not open the gallery.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _maxPdfPages = 5;
  static const _maxPdfRenderDimension = 2400.0;

  Future<void> _importPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      const pdfType = XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
      );
      final picked = await openFile(acceptedTypeGroups: [pdfType]);
      final path = picked?.path;
      if (path == null) return;

      // Render pages to images so the PDF flows through the exact same
      // OCR/extraction pipeline as a camera scan.
      final pdf = await PdfDocument.openFile(path);
      final tempDir = await getTemporaryDirectory();
      final pagePaths = <String>[];
      final pageCount = pdf.pagesCount.clamp(0, _maxPdfPages);
      for (var i = 1; i <= pageCount; i++) {
        final page = await pdf.getPage(i);
        // Cap render size — an oversized page (large-format PDF) shouldn't
        // decode into an unbounded pixel buffer any more than a photo should.
        final scale = math.min(
          2.0,
          _maxPdfRenderDimension / math.max(page.width, page.height),
        );
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.jpeg,
        );
        await page.close();
        if (rendered == null) continue;
        final file = File(
          p.join(tempDir.path,
              'pdf_page_${DateTime.now().millisecondsSinceEpoch}_$i.jpg'),
        );
        await file.writeAsBytes(rendered.bytes, flush: true);
        pagePaths.add(file.path);
      }
      await pdf.close();

      if (pagePaths.isEmpty) {
        _showError('Could not read any pages from that PDF.');
        return;
      }
      if (mounted) {
        context.pushReplacement('/scanning', extra: pagePaths);
      }
    } catch (_) {
      _showError('Could not import that PDF.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add document')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                index: 0,
                child: Text(
                  'The vault will read it, extract every detail, and file it '
                  'for you.',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
              const Gap(24),
              FadeSlideIn(
                index: 1,
                child: _CaptureOption(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan with camera',
                  subtitle:
                      'Auto-detects edges, fixes perspective and lighting',
                  accent: true,
                  onTap: _scanWithCamera,
                ),
              ),
              const Gap(12),
              FadeSlideIn(
                index: 2,
                child: _CaptureOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  subtitle: 'Use a photo you already have',
                  onTap: _pickFromGallery,
                ),
              ),
              const Gap(12),
              FadeSlideIn(
                index: 3,
                child: _CaptureOption(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Import a PDF',
                  subtitle: 'First $_maxPdfPages pages are read like a scan',
                  onTap: _importPdf,
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                index: 3,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const Gap(6),
                        Flexible(
                          child: Text(
                            AppConfig.aiEnabled
                                ? 'Stored encrypted on your device. Only the image is sent to AI for reading.'
                                : 'Stored encrypted on your device. Processed fully offline.',
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;

  const _CaptureOption({
    required this.icon,
    required this.title,
    required this.subtitle,
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent ? context.scheme.primary : context.scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: accent ? context.scheme.onPrimary : context.scheme.onSurface,
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
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
