import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/models/profile_model.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/profile_section_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              onPressed: () => _showEditProfileSheet(context, ref, profile),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            children: [
              const Gap(16),
              _buildProfileHeader(profile, authState, ref),
              const Gap(20),
              _buildCompletenessCard(profile),
              const Gap(20),
              _buildInfoCard(profile),
              const Gap(20),
              _buildSections(profile),
              const Gap(24),
              _buildAuthSection(context, authState, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    UserProfile profile,
    AuthState authState,
    WidgetRef ref,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (authState.isAuthenticated && authState.photoUrl != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(14),
          Text(
            profile.name.isNotEmpty ? profile.name : 'Your Name',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          Text(
            profile.email.isNotEmpty ? profile.email : 'Not signed in',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          if (profile.phone.isNotEmpty) ...[
            const Gap(2),
            Text(
              profile.phone,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const Gap(20),
          _buildStatsRow(profile),
        ],
      ),
    );
  }

  Widget _buildStatsRow(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _statItem(
            'Documents',
            profile.documentCount.toString(),
            Icons.description_outlined,
          ),
          _dividerVertical(),
          _statItem(
            'Profiles',
            profile.profileCount.toString(),
            Icons.person_outline,
          ),
          _dividerVertical(),
          _statItem(
            'Scans',
            profile.recentScans.toString(),
            Icons.document_scanner_outlined,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const Gap(6),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerVertical() {
    return Container(width: 1, height: 40, color: AppColors.borderLight);
  }

  Widget _buildCompletenessCard(UserProfile profile) {
    final missing = <String>[];
    if (!profile.hasName) missing.add('name');
    if (!profile.hasEmail) missing.add('email');
    if (!profile.hasPhone) missing.add('phone number');

    final suggestion = profile.isComplete
        ? 'Your profile is complete!'
        : 'Add your ${missing.join(' & ')} for autofill.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 32,
            lineWidth: 6,
            percent: profile.completeness,
            backgroundColor: AppColors.bgTertiary,
            progressColor: profile.isComplete
                ? AppColors.success
                : AppColors.accent,
            circularStrokeCap: CircularStrokeCap.round,
            center: Text(
              '${profile.completenessPercent}%',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Completeness',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(4),
                Text(
                  suggestion,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: profile.isComplete
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Information',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'All fields optional',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _profileField(
            icon: Icons.person_outline,
            label: 'Name',
            value: profile.name,
            isComplete: profile.hasName,
          ),
          if (profile.hasName || profile.hasEmail || profile.hasPhone)
            const Divider(height: 24),
          _profileField(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile.email,
            isComplete: profile.hasEmail,
          ),
          if (profile.hasEmail || profile.hasPhone) const Divider(height: 24),
          _profileField(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: profile.phone,
            isComplete: profile.hasPhone,
          ),
        ],
      ),
    );
  }

  Widget _profileField({
    required IconData icon,
    required String label,
    required String value,
    required bool isComplete,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isComplete
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isComplete ? AppColors.success : AppColors.warning,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : 'Not set',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: value.isNotEmpty
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                  fontWeight: value.isNotEmpty
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (!isComplete)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildSections(UserProfile profile) {
    if (profile.sections.isEmpty) return const SizedBox();

    final iconMap = {
      'person': Icons.person_rounded,
      'school': Icons.school_rounded,
      'phone': Icons.phone_rounded,
      'people': Icons.people_rounded,
      'description': Icons.description_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Profile Sections',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...profile.sections.map(
          (s) => ProfileSectionTile(
            name: s.name,
            icon: iconMap[s.iconName] ?? Icons.circle_outlined,
            isComplete: s.isComplete,
            color: _sectionColor(s.iconName),
          ),
        ),
      ],
    );
  }

  Color _sectionColor(String iconName) {
    switch (iconName) {
      case 'person':
        return AppColors.accent;
      case 'school':
        return AppColors.categoryEducation;
      case 'phone':
        return AppColors.categoryFinance;
      case 'people':
        return AppColors.categoryFamily;
      case 'description':
        return AppColors.categoryOther;
      default:
        return AppColors.accent;
    }
  }

  Widget _buildAuthSection(
    BuildContext context,
    AuthState authState,
    WidgetRef ref,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud Sync',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      authState.isAuthenticated
                          ? 'Synced as ${authState.email}'
                          : 'Sign in to sync across devices',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (authState.isAuthenticated)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                if (authState.isAuthenticated) {
                  ref.read(authProvider.notifier).signOut();
                } else {
                  ref.read(authProvider.notifier).signInWithGoogle();
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: authState.isAuthenticated
                    ? AppColors.error.withValues(alpha: 0.08)
                    : AppColors.accent.withValues(alpha: 0.08),
                foregroundColor: authState.isAuthenticated
                    ? AppColors.error
                    : AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    authState.isAuthenticated
                        ? Icons.logout_rounded
                        : Icons.g_mobiledata_rounded,
                    size: 20,
                  ),
                  const Gap(8),
                  Text(
                    authState.isAuthenticated
                        ? 'Sign Out'
                        : 'Sign in with Google',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final nameCtrl = TextEditingController(text: profile.name);
    final emailCtrl = TextEditingController(text: profile.email);
    final phoneCtrl = TextEditingController(text: profile.phone);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Edit Profile',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _editField(
              controller: nameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            _editField(
              controller: emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _editField(
              controller: phoneCtrl,
              label: 'Mobile Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref
                      .read(profileProvider.notifier)
                      .setName(nameCtrl.text.trim());
                  ref
                      .read(profileProvider.notifier)
                      .setEmail(emailCtrl.text.trim());
                  ref
                      .read(profileProvider.notifier)
                      .setPhone(phoneCtrl.text.trim());
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.bgSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }
}
