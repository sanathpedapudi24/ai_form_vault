import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/models/person_model.dart';
import '../../core/providers/person_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/section_header.dart';

/// Reviews AI-suggested relationships (confirm/reject) and shows the
/// confirmed family graph as a simple list — nothing is assumed without
/// the user's say-so.
class RelationshipsScreen extends ConsumerWidget {
  const RelationshipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(identityGraphProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relationships')),
      body: SafeArea(
        child: graph.persons.length <= 1 && graph.pending.isEmpty
            ? EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No connections yet',
                message:
                    'When a document mentions someone else — a parent, '
                    'spouse, or guardian — they\'ll show up here for you to confirm.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (graph.pending.isNotEmpty) ...[
                    FadeSlideIn(
                      index: 0,
                      child: SectionHeader(
                        title: 'Needs your confirmation',
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      ),
                    ),
                    for (var i = 0; i < graph.pending.length; i++)
                      FadeSlideIn(
                        index: 1 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PendingCard(
                            relationship: graph.pending[i],
                            graph: graph,
                          ),
                        ),
                      ),
                    const Gap(20),
                  ],
                  if (graph.confirmed.isNotEmpty) ...[
                    FadeSlideIn(
                      index: 10,
                      child: const SectionHeader(
                        title: 'Confirmed',
                        padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                      ),
                    ),
                    for (var i = 0; i < graph.confirmed.length; i++)
                      FadeSlideIn(
                        index: 11 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ConfirmedTile(
                            relationship: graph.confirmed[i],
                            graph: graph,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  final Relationship relationship;
  final IdentityGraphState graph;

  const _PendingCard({required this.relationship, required this.graph});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = graph.personById(relationship.fromPersonId);
    final to = graph.personById(relationship.toPersonId);
    if (from == null || to == null) return const SizedBox.shrink();

    return AppCard(
      border: BorderSide(color: AppColors.accentWashBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(person: from),
              const Gap(10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.body,
                    children: [
                      TextSpan(
                        text: from.displayName,
                        style: AppTextStyles.itemTitle,
                      ),
                      const TextSpan(text: ' is '),
                      TextSpan(
                        text: 'the ${relationship.type.label.toLowerCase()}',
                        style: AppTextStyles.itemTitle,
                      ),
                      TextSpan(text: ' of ${to.displayName}?'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (relationship.evidence.isNotEmpty) ...[
            const Gap(10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      relationship.evidence,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Not quite',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(identityGraphProvider.notifier)
                        .reject(relationship.id);
                  },
                ),
              ),
              const Gap(10),
              Expanded(
                child: PrimaryButton(
                  label: 'Confirm',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(identityGraphProvider.notifier)
                        .confirm(relationship.id);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmedTile extends StatelessWidget {
  final Relationship relationship;
  final IdentityGraphState graph;

  const _ConfirmedTile({required this.relationship, required this.graph});

  @override
  Widget build(BuildContext context) {
    final from = graph.personById(relationship.fromPersonId);
    final to = graph.personById(relationship.toPersonId);
    if (from == null || to == null) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Avatar(person: from),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(from.displayName, style: AppTextStyles.itemTitle),
                const Gap(2),
                Text(
                  '${relationship.type.label} of ${to.displayName}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (from.documentCount > 0)
            Text(
              '${from.documentCount} doc${from.documentCount == 1 ? '' : 's'}',
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Person person;

  const _Avatar({required this.person});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: person.isUser ? AppColors.accent : AppColors.bgSunken,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          person.initial,
          style: AppTextStyles.label.copyWith(
            color: person.isUser ? AppColors.textOnAccent : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
