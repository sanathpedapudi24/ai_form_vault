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
import '../../core/theme/motion.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
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
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(userName: userName),
              ),
            ),
            if (pending.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SuggestionsBanner(count: pending.length),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _StatsRow(
                  documents: docs.length,
                  people: graph.persons.length,
                  connections: graph.confirmed.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(top: 28),
              sliver: SliverToBoxAdapter(
                child: _QuickActionsRow(),
              ),
            ),
            if (recent.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Recent',
                    actionLabel: 'See all',
                    onAction: () => context.go('/vault'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 12),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const Gap(12),
                      itemBuilder: (context, i) => _RecentDocumentCard(
                        document: recent[i],
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: const _FirstScanCard(),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
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
      color: context.scheme.surfaceContainerLow,
      shape: CircleBorder(side: BorderSide(color: context.scheme.outlineVariant)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 17, color: context.scheme.onSurfaceVariant),
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
      color: context.scheme.primaryContainer,
      border: BorderSide(color: AppColors.accentWashBorder),
      shadow: false,
      onTap: () => context.go('/people'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_alt_outlined,
              color: context.scheme.onPrimary,
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
          Icon(
            Icons.chevron_right_rounded,
            color: context.scheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

// --- Stats: three individual cards instead of a monolithic row ---

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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: documents,
            label: 'Documents',
            icon: Icons.description_outlined,
            color: AppColors.accent,
          ),
        ),
        const Gap(10),
        Expanded(
          child: _StatCard(
            value: people,
            label: 'People',
            icon: Icons.person_outline_rounded,
            color: AppColors.info,
          ),
        ),
        const Gap(10),
        Expanded(
          child: _StatCard(
            value: connections,
            label: 'Links',
            icon: Icons.link_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const Gap(8),
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            tween: IntTween(begin: 0, end: value),
            builder: (context, animated, _) => Text(
              '$animated',
              style: AppTextStyles.statNumber.copyWith(fontSize: 24),
            ),
          ),
          const Gap(2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// --- Quick actions: horizontal scrollable row ---

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _QuickActionCard(
            icon: Icons.document_scanner_outlined,
            title: 'Scan',
            accent: true,
            onTap: () => context.push('/capture'),
          ),
          const Gap(10),
          _QuickActionCard(
            icon: Icons.people_alt_outlined,
            title: 'People',
            onTap: () => context.go('/people'),
          ),
          const Gap(10),
          _QuickActionCard(
            icon: Icons.search_rounded,
            title: 'Search',
            onTap: () => context.push('/search'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool accent;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 100,
        decoration: BoxDecoration(
          color: accent
              ? context.scheme.inverseSurface
              : context.scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: accent
              ? null
              : Border.all(color: context.scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent
                    ? AppColors.surfaceInverseRaised
                    : context.scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: accent
                    ? context.scheme.onInverseSurface
                    : context.scheme.onPrimaryContainer,
              ),
            ),
            const Gap(10),
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                color: accent
                    ? context.scheme.onInverseSurface
                    : context.scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Recent documents: horizontal scrollable cards ---

class _RecentDocumentCard extends StatelessWidget {
  final DocumentModel document;

  const _RecentDocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/document/${document.id}'),
      child: SizedBox(
        width: 140,
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: document.thumbFile.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: VaultImage(
                          fileName: document.thumbFile,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: CategoryVisual.colorOf(document.category)
                              .withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Center(
                          child: CategoryVisual(
                            category: document.category,
                            size: 40,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.displayTitle,
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      document.dateFormatted,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Empty state ---

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
                  color: context.scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 16,
                      color: context.scheme.onPrimary,
                    ),
                    const Gap(8),
                    Text(
                      'Scan your first document',
                      style: AppTextStyles.buttonSmall.copyWith(
                        color: context.scheme.onPrimary,
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
