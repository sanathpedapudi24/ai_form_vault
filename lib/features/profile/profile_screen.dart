import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/document_model.dart';
import '../../core/models/person_model.dart';
import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/person_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_card.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(identityGraphProvider);
    final docs = ref.watch(documentsProvider);
    final settings = ref.watch(settingsProvider);
    final lock = ref.watch(appLockProvider);
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
                child: _ProfileHeader(
                  user: user,
                  documentCount: docs.length,
                  onEditName: () => _editName(context, ref, user),
                ),
              ),
            const Gap(24),
            FadeSlideIn(
              index: 1,
              child: SectionHeader(
                title: 'Identity facts',
                actionLabel: docs.isEmpty ? null : 'View all',
                onAction: docs.isEmpty ? null : () => context.go('/people'),
              ),
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
                  : AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < facts.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, indent: 16, endIndent: 16),
                            FadeSlideIn(
                              index: 2 + i,
                              child: _FactRow(fact: facts[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const Gap(24),
            FadeSlideIn(
              index: 3,
              child: const SectionHeader(title: 'People & connections'),
            ),
            FadeSlideIn(
              index: 4,
              child: _NavCard(
                icon: Icons.people_alt_outlined,
                title: 'Relationships',
                subtitle: graph.pending.isNotEmpty
                    ? '${graph.pending.length} to review'
                    : '${graph.confirmed.length} connected',
                highlight: graph.pending.isNotEmpty,
                onTap: () => context.go('/people'),
              ),
            ),
            const Gap(24),
            FadeSlideIn(
              index: 5,
              child: const SectionHeader(title: 'Security'),
            ),
            FadeSlideIn(
              index: 6,
              child: lock.hasPin
                  ? Column(
                      children: [
                        _NavCard(
                          icon: Icons.password_rounded,
                          title: 'Change PIN',
                          subtitle: 'Update your 4-digit unlock code',
                          onTap: () => context.push('/settings/change-pin'),
                        ),
                        if (lock.biometricAvailable) ...[
                          const Gap(10),
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Biometric unlock',
                                style: AppTextStyles.itemTitle,
                              ),
                              subtitle: Text(
                                'Use your fingerprint or face instead of the PIN',
                                style: AppTextStyles.caption,
                              ),
                              value: lock.biometricEnabled,
                              activeThumbColor: Colors.white,
                              onChanged: (v) => ref
                                  .read(appLockProvider.notifier)
                                  .setBiometricEnabled(v),
                            ),
                          ),
                        ],
                        const Gap(10),
                        _NavCard(
                          icon: Icons.lock_open_outlined,
                          title: 'Turn off app lock',
                          subtitle: 'Remove the PIN and biometric gate',
                          onTap: () => context.push('/settings/disable-lock'),
                        ),
                      ],
                    )
                  : _NavCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Set up app lock',
                      subtitle: 'Protect your vault with a PIN or biometrics',
                      highlight: true,
                      onTap: () => context.push('/settings/setup-pin'),
                    ),
            ),
            const Gap(24),
            FadeSlideIn(
              index: 7,
              child: const SectionHeader(title: 'Local backup'),
            ),
            const FadeSlideIn(index: 7, child: BackupSection()),
            const Gap(24),
            FadeSlideIn(
              index: 7,
              child: const SectionHeader(title: 'Settings'),
            ),
            FadeSlideIn(
              index: 8,
              child: Column(
                children: [
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                  const Gap(10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                  const Gap(10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                  const Gap(10),
                  _NavCard(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    subtitle: ref.watch(authStateProvider).asData?.value?.email ??
                        ref.watch(authStateProvider).asData?.value?.phoneNumber ??
                        'Signed in',
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _ProfileHeader extends StatelessWidget {
  final Person user;
  final int documentCount;
  final VoidCallback onEditName;

  const _ProfileHeader({
    required this.user,
    required this.documentCount,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentWash,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.initial,
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.accentDeep,
                ),
              ),
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onEditName,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          style: AppTextStyles.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap(4),
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const Gap(3),
                Text(
                  '$documentCount document${documentCount == 1 ? '' : 's'} in vault',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final PersonFact fact;

  const _FactRow({required this.fact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(FactKeys.labelFor(fact.factKey), style: AppTextStyles.label),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fact.value,
              style: (FactKeys.sensitive.contains(fact.factKey)
                      ? AppTextStyles.mono
                      : AppTextStyles.body)
                  .copyWith(fontSize: 14.5),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (fact.verified) ...[
            const Gap(6),
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlight = false,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: highlight ? AppColors.accentWash : AppColors.bgSunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: highlight ? AppColors.accentDeep : AppColors.textPrimary,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.itemTitle),
                const Gap(2),
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
