import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/relationship_model.dart';
import '../../core/providers/relationship_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/accent_button.dart';
import 'widgets/family_graph.dart';
import 'widgets/relationship_node.dart';
import 'widgets/relationship_review_sheet.dart';

class RelationshipsScreen extends ConsumerWidget {
  const RelationshipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationships = ref.watch(relationshipProvider);
    final user = relationships.isEmpty
        ? null
        : relationships.firstWhere(
            (p) => p.isUser,
            orElse: () => relationships.first,
          );

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          'Identity & Relationships',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  relationships.isEmpty
                      ? 'Add family members'
                      : 'AI builds your family graph',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Gap(24),
              Expanded(
                child: relationships.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                color: AppColors.accent,
                                size: 36,
                              ),
                            ),
                            const Gap(16),
                            Text(
                              'No relationships yet',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              'Add a relationship to build your family graph',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return _buildFamilyGraph(
                            constraints,
                            relationships,
                            user,
                          );
                        },
                      ),
              ),
              AccentButton(
                label: 'Add Relationship',
                icon: Icons.person_add_rounded,
                isExpanded: true,
                onPressed: () => _showAddRelationshipDialog(context, ref),
              ),
              const Gap(10),
              AccentButton(
                label: 'Review Suggestion',
                icon: Icons.auto_awesome_rounded,
                isOutlined: true,
                isExpanded: true,
                onPressed: () async {
                  final type = await RelationshipReviewSheet.show(
                    context,
                    personName: 'Priya',
                  );
                  if (type != null && context.mounted) {
                    ref
                        .read(relationshipProvider.notifier)
                        .addRelationship(
                          PersonNode(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            name: 'Priya',
                            relationship: type,
                            documentCount: 1,
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added as ${type.label}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const Gap(16),
              Text(
                'AI detects people in documents and helps you confirm relationships.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddRelationshipDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Relationship'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select relationship type:'),
            const SizedBox(height: 8),
            ...RelationshipType.values.map((type) {
              if (type == RelationshipType.other) return const SizedBox();
              return ListTile(
                title: Text(type.label),
                leading: Icon(
                  type == RelationshipType.father ||
                          type == RelationshipType.brother
                      ? Icons.male_rounded
                      : Icons.female_rounded,
                ),
                onTap: () {
                  ref
                      .read(relationshipProvider.notifier)
                      .addRelationship(
                        PersonNode(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text.trim(),
                          relationship: type,
                          documentCount: 0,
                        ),
                      );
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyGraph(
    BoxConstraints constraints,
    List<PersonNode> relationships,
    PersonNode? user,
  ) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final centerX = width / 2;
    final centerY = height / 2;

    final familyMembers = relationships.where((p) => !p.isUser).toList();

    if (familyMembers.isEmpty) {
      return Center(
        child: Text(
          'Add family members to see the graph',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    // Calculate positions for up to 4 family members
    final positions = <Offset>[
      Offset(centerX - 90, centerY - 120),
      Offset(centerX + 90, centerY - 120),
      Offset(centerX - 90, centerY + 120),
      Offset(centerX + 90, centerY + 120),
    ];

    final connections = familyMembers.take(4).map((p) {
      final idx = familyMembers.indexOf(p);
      return [Offset(centerX, centerY), positions[idx % positions.length]];
    }).toList();

    const nodeWidth = 100.0;
    const userNodeWidth = 120.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: FamilyGraphPainter(connections: connections),
        ),
        ...familyMembers.take(4).map((person) {
          final idx = familyMembers.indexOf(person);
          final pos = positions[idx % positions.length];
          return Positioned(
            left: pos.dx - nodeWidth / 2,
            top: pos.dy - 50,
            width: nodeWidth,
            child: RelationshipNodeWidget(person: person, radius: 32),
          );
        }),
        if (user != null)
          Positioned(
            left: centerX - userNodeWidth / 2,
            top: centerY - 60,
            width: userNodeWidth,
            child: RelationshipNodeWidget(
              person: user,
              radius: 40,
              isHighlighted: true,
            ),
          ),
      ],
    );
  }
}
