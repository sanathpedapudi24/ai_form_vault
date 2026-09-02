import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/document_model.dart';
import '../../core/models/person_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/person_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/section_header.dart';
import 'widgets/backup_section.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _editName(BuildContext context, WidgetRef ref, Person user) {
    final controller = TextEditingController(text: user.displayName);
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
            Text('Your name', style: AppTextStyles.titleSmall),
            const Gap(14),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.body,
              onSubmitted: (v) {
                ref
                    .read(identityGraphProvider.notifier)
                    .renamePerson(user.id, v);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConflictResolution(
    BuildContext context,
    WidgetRef ref,
    PersonFact fact,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conflicting values for ${FactKeys.labelFor(fact.factKey)}',
                style: AppTextStyles.titleSmall,
              ),
              const Gap(6),
              Text(
                'Two documents gave different readings. Pick the correct one.',
                style: AppTextStyles.bodySecondary,
              ),
              const Gap(16),
              AppCard(
                onTap: () {
                  ref
                      .read(identityGraphProvider.notifier)
                      .resolveConflictKeepCurrent(fact.id);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keep current', style: AppTextStyles.label),
                          const Gap(2),
                          Text(
                            fact.value,
                            style: AppTextStyles.body.copyWith(fontSize: 14.5),
                          ),
                        ],
                      ),
                    ),
                    ConfidenceBadge(confidence: fact.confidence, compact: true),
                  ],
                ),
              ),
              const Gap(10),
              AppCard(
                onTap: () {
                  ref
                      .read(identityGraphProvider.notifier)
                      .resolveConflictKeepOriginal(fact.id);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Use other value', style: AppTextStyles.label),
                          const Gap(2),
                          Text(
                            fact.conflictValue,
                            style: AppTextStyles.body.copyWith(fontSize: 14.5),
                          ),
                        ],
                      ),
                    ),
                    ConfidenceBadge(confidence: 0.6, compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(identityGraphProvider);
    final docs = ref.watch(documentsProvider);
    final settings = ref.watch(settingsProvider);
    final user = graph.user;
    final factsAsync = user != null
        ? ref.watch(personFactsProvider(user.id))
        : const AsyncValue<List<PersonFact>>.data([]);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (user != null)
              FadeSlideIn(
                index: 0,
                child: _ProfileHero(
                  user: user,
                  documentCount: docs.length,
                  factCount: factsAsync.valueOrNull?.length ?? 0,
                  onEditName: () => _editName(context, ref, user),
                ),
              ),
            const Gap(28),
            FadeSlideIn(
              index: 1,
              child: const SectionHeader(title: 'Identity facts'),
            ),
            factsAsync.when(
              data: (facts) => facts.isEmpty
                  ? FadeSlideIn(
                      index: 2,
                      child: AppCard(
                        child: Text(
                          'Scan an identity document to build your profile automatically.',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                    )
                  : _FactGrid(
                      facts: facts,
                      onResolveConflict: (fact) =>
                          _showConflictResolution(context, ref, fact),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const Gap(28),
            FadeSlideIn(
              index: 3,
              child: const SectionHeader(title: 'Connections'),
            ),
            FadeSlideIn(
              index: 4,
              child: _ConnectionCard(
                pending: graph.pending.length,
                confirmed: graph.confirmed.length,
                onTap: () => context.go('/people'),
              ),
            ),
            const Gap(28),
            FadeSlideIn(
              index: 5,
              child: const SectionHeader(title: 'Backup'),
            ),
            const FadeSlideIn(index: 5, child: BackupSection()),
            const Gap(28),
            FadeSlideIn(
              index: 6,
              child: const SectionHeader(title: 'Preferences'),
            ),
            FadeSlideIn(
              index: 7,
              child: _PreferencesSection(settings: settings, ref: ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width profile hero with avatar, name, and quick stats.
class _ProfileHero extends StatelessWidget {
  final Person user;
  final int documentCount;
  final int factCount;
  final VoidCallback onEditName;

  const _ProfileHero({
    required this.user,
    required this.documentCount,
    required this.factCount,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.initial,
                style: AppTextStyles.display.copyWith(
                  color: context.scheme.onPrimaryContainer,
                  fontSize: 28,
                ),
              ),
            ),
          ),
          const Gap(14),
          GestureDetector(
            onTap: onEditName,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user.displayName,
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(6),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeroStat(value: documentCount, label: 'docs'),
              const _HeroStatDivider(),
              _HeroStat(value: factCount, label: 'facts'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final int value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text('$value', style: AppTextStyles.statNumber.copyWith(fontSize: 22)),
          const Gap(2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  const _HeroStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: context.scheme.outlineVariant);
  }
}

/// Fact grid: 2-column layout for identity facts instead of a monolithic list.
class _FactGrid extends StatelessWidget {
  final List<PersonFact> facts;
  final ValueChanged<PersonFact> onResolveConflict;

  const _FactGrid({required this.facts, required this.onResolveConflict});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fact in facts)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            child: _FactChip(
              fact: fact,
              onTap: fact.hasConflict ? () => onResolveConflict(fact) : null,
            ),
          ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  final PersonFact fact;
  final VoidCallback? onTap;

  const _FactChip({required this.fact, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    FactKeys.labelFor(fact.factKey),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fact.hasConflict)
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: AppColors.warning,
                  )
                else if (fact.verified)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.success,
                  ),
              ],
            ),
            const Gap(6),
            Text(
              fact.value,
              style: (FactKeys.sensitive.contains(fact.factKey)
                      ? AppTextStyles.mono
                      : AppTextStyles.body)
                  .copyWith(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Connection card with visual indicator.
class _ConnectionCard extends StatelessWidget {
  final int pending;
  final int confirmed;
  final VoidCallback onTap;

  const _ConnectionCard({
    required this.pending,
    required this.confirmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pending > 0
                  ? AppColors.accentWash
                  : context.scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.people_alt_outlined,
              size: 22,
              color: pending > 0 ? AppColors.accent : context.scheme.onSurface,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('People & relationships', style: AppTextStyles.itemTitle),
                const Gap(2),
                Text(
                  pending > 0
                      ? '$pending to review · $confirmed connected'
                      : '$confirmed connected',
                  style: AppTextStyles.caption.copyWith(
                    color: pending > 0 ? AppColors.warning : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// Preferences section: toggles grouped together.
class _PreferencesSection extends StatelessWidget {
  final SettingsState settings;
  final WidgetRef ref;

  const _PreferencesSection({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('System-wide autofill', style: AppTextStyles.itemTitle),
            subtitle: Text(
              settings.autofillEnabled
                  ? (settings.autofillServiceActive
                      ? 'Active — filling forms in other apps'
                      : 'Enabled — finish setup in Android settings')
                  : 'Let other apps request your saved details',
              style: AppTextStyles.caption,
            ),
            value: settings.autofillEnabled,
            activeThumbColor: Colors.white,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setAutofillEnabled(v),
          ),
        ),
        const Gap(8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Expiry reminders', style: AppTextStyles.itemTitle),
            subtitle: Text(
              'Notify me 90, 30, and 7 days before a document expires',
              style: AppTextStyles.caption,
            ),
            value: settings.remindersEnabled,
            activeThumbColor: Colors.white,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setRemindersEnabled(v),
          ),
        ),
        const Gap(8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Dark mode', style: AppTextStyles.itemTitle),
            subtitle: Text(
              'Warm dark theme for low light',
              style: AppTextStyles.caption,
            ),
            value: settings.darkMode,
            activeThumbColor: Colors.white,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setDarkMode(v),
          ),
        ),
        const Gap(8),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          subtitle: ref.watch(authStateProvider).asData?.value?.email ??
              ref.watch(authStateProvider).asData?.value?.phoneNumber ??
              'Signed in',
          onTap: () => _confirmSignOut(context, ref),
          danger: true,
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sign out?', style: AppTextStyles.titleSmall),
              const Gap(6),
              Text(
                'Your documents stay on this device. You\'ll need to sign in '
                'again to open the vault.',
                style: AppTextStyles.bodySecondary,
              ),
              const Gap(16),
              PrimaryButton(
                label: 'Sign out',
                danger: true,
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable settings tile — replaces the repetitive _NavCard pattern.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: danger
                  ? AppColors.error.withValues(alpha: 0.1)
                  : context.scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: danger ? AppColors.error : context.scheme.onSurface,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.itemTitle.copyWith(
                    color: danger ? AppColors.error : null,
                  ),
                ),
                const Gap(2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
