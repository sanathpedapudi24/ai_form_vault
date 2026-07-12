import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/motion.dart';
import '../../shared/widgets/app_buttons.dart';

class _Page {
  final IconData icon;
  final String title;
  final String body;

  const _Page({required this.icon, required this.title, required this.body});
}

/// First-run introduction: what the app does and — most importantly for an
/// app asking to photograph your Aadhaar card — why it can be trusted.
/// Shown once, before PIN setup.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _Page(
      icon: Icons.document_scanner_outlined,
      title: 'Scan once,\nnever type it again',
      body:
          'Photograph your Aadhaar, PAN, passport or marksheets. The vault '
          'reads them, extracts every detail, and organizes everything by '
          'person — not by folder.',
    ),
    _Page(
      icon: Icons.phonelink_lock_outlined,
      title: 'Nothing ever\nleaves your phone',
      body:
          'Documents are encrypted on your device and processed entirely '
          'on-device. No account, no cloud, no AI service ever sees them. '
          'That\'s a design guarantee, not a settings toggle.',
    ),
    _Page(
      icon: Icons.edit_document,
      title: 'Fill any form\nin seconds',
      body:
          'Snap a photo of a blank form and the vault fills it from your '
          'saved details — or let it autofill forms in other apps '
          'system-wide.',
    ),
  ];

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(duration: AppMotion.base, curve: AppMotion.ease);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.buttonSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.accentWash,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 32,
                            color: AppColors.accentDeep,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(page.title, style: AppTextStyles.display),
                        const SizedBox(height: 16),
                        Text(page.body, style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, 28),
              child: Row(
                children: [
                  // Page dots.
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.ease,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.accent
                            : AppColors.bgDeep,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  PrimaryButton(
                    label: isLast ? 'Set up my vault' : 'Next',
                    icon: isLast ? Icons.lock_outline_rounded : null,
                    expanded: false,
                    onPressed: _next,
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
