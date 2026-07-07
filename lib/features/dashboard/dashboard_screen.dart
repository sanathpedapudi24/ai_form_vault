import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_model.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/person_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/vault_image.dart';
import 'widgets/category_visual.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    final recent = ref.watch(recentDocumentsProvider);
    final graph = ref.watch(identityGraphProvider);
    final pending = graph.pending;

    final user = graph.user;
    final userName = (user != null && user.displayName != 'You')
        ? user.displayName.split(' ').first
        : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            FadeSlideIn(
              index: 0,
              child: _Header(userName: userName),
            ),
            const Gap(24),
            if (pending.isNotEmpty) ...[
              FadeSlideIn(
                index: 1,
                child: _SuggestionsBanner(count: pending.length),
              ),
              const Gap(16),
            ],
            FadeSlideIn(index: 2, child: const _QuickActions()),
            const Gap(24),
            FadeSlideIn(
              index: 3,
              child: _StatsRow(
                documents: docs.length,
                people: graph.persons.length,
                connections: graph.confirmed.length,
              ),
            ),
            const Gap(28),
            if (recent.isNotEmpty) ...[
              FadeSlideIn(
                index: 4,
                child: SectionHeader(
                  title: 'Recent documents',
                  actionLabel: 'See all',
                  onAction: () => context.go('/vault'),
                ),
              ),
              for (var i = 0; i < recent.length; i++)
                FadeSlideIn(
                  index: 5 + i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecentDocumentTile(document: recent[i]),
                  ),
                ),
            ] else
              FadeSlideIn(
                index: 4,
                child: const _FirstScanCard(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? userName;

  const _Header({this.userName});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
                style: AppTextStyles.overline,
              ),
              const Gap(6),
              Text(
                userName != null ? '$_greeting,\n$userName' : _greeting,
                style: AppTextStyles.display,
              ),
            ],
          ),
        ),
        Row(
          children: [
            _HeaderIconButton(
              icon: Icons.search_rounded,
              onTap: () => context.push('/search'),
            ),
            const Gap(8),
            TagChip(
              label: AppConfig.aiEnabled ? 'AI on' : 'On-device',
              color: AppConfig.aiEnabled ? AppColors.success : AppColors.info,
              icon: AppConfig.aiEnabled
                  ? Icons.auto_awesome_rounded
                  : Icons.offline_bolt_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 17, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SuggestionsBanner extends StatelessWidget {
  final int count;

  const _SuggestionsBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.accentWash,
      border: const BorderSide(color: AppColors.accentWashBorder),
      shadow: false,
      onTap: () => context.push('/relationships'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: AppColors.textOnAccent,
              size: 20,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 relationship to review'
                      : '$count relationships to review',
                  style: AppTextStyles.itemTitle,
                ),
                const Gap(2),
                Text(
                  'The vault noticed people in your documents. Confirm who they are.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.accentDeep,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.document_scanner_outlined,
            title: 'Scan\ndocument',
            accent: true,
            onTap: () => context.push('/capture'),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _ActionCard(
            icon: Icons.edit_document,
            title: 'Snap\nto fill',
            onTap: () => context.push('/snap-to-fill'),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool accent;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: accent ? AppColors.surfaceInverse : AppColors.surface,
      border: accent
          ? const BorderSide(color: AppColors.surfaceInverse)
          : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent ? AppColors.surfaceInverseRaised : AppColors.accentWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accent ? AppColors.textOnInverse : AppColors.accentDeep,
            ),
          ),
          const Gap(14),
          Text(
            title,
            style: AppTextStyles.headline.copyWith(
              color: accent ? AppColors.textOnInverse : AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int documents;
  final int people;
  final int connections;

  const _StatsRow({
    required this.documents,
    required this.people,
    required this.connections,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          _Stat(value: documents, label: 'Documents'),
          const _StatDivider(),
          _Stat(value: people, label: 'People'),
          const _StatDivider(),
          _Stat(value: connections, label: 'Connections'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            tween: IntTween(begin: 0, end: value),
            builder: (context, animated, _) =>
                Text('$animated', style: AppTextStyles.statNumber),
          ),
          const Gap(2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }
}

class _RecentDocumentTile extends StatelessWidget {
  final DocumentModel document;

  const _RecentDocumentTile({required this.document});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/document/${document.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          document.thumbFile.isNotEmpty
              ? VaultImage(fileName: document.thumbFile, width: 48, height: 48)
              : CategoryVisual(category: document.category, size: 48),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.displayTitle,
                  style: AppTextStyles.itemTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(3),
                Text(
                  [
                    if (document.ownerName.isNotEmpty) document.ownerName,
                    document.dateFormatted,
                  ].join(' · '),
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(8),
          ConfidenceBadge(confidence: document.confidence, compact: true),
          const Gap(10),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _FirstScanCard extends StatelessWidget {
  const _FirstScanCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      onTap: () => context.push('/capture'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Store once.\nUnderstand forever.', style: AppTextStyles.title),
          const Gap(10),
          Text(
            'Scan your first document — an Aadhaar card, PAN, marksheet or '
            'passport. The vault reads it, organizes it, and remembers every '
            'detail so you never type it again.',
            style: AppTextStyles.bodySecondary,
          ),
          const Gap(18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.document_scanner_outlined,
                      size: 16,
                      color: AppColors.textOnAccent,
                    ),
                    const Gap(8),
                    Text(
                      'Scan your first document',
                      style: AppTextStyles.buttonSmall.copyWith(
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
