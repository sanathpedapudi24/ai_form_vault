import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/app_lock_provider.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/providers/person_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';

/// Profile section for passphrase-protected backup export and restore.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<String?> _askPassphrase({
    required String title,
    required String subtitle,
    required String buttonLabel,
    bool confirm = false,
  }) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleSmall),
            const Gap(6),
            Text(subtitle, style: AppTextStyles.bodySecondary),
            const Gap(14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'Passphrase'),
            ),
            if (confirm) ...[
              const Gap(10),
              TextField(
                controller: confirmController,
                obscureText: true,
                style: AppTextStyles.body,
                decoration:
                    const InputDecoration(hintText: 'Confirm passphrase'),
              ),
            ],
            const Gap(16),
            PrimaryButton(
              label: buttonLabel,
              onPressed: () {
                final pass = controller.text;
                if (pass.length < 6) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Use at least 6 characters.'),
                    ),
                  );
                  return;
                }
                if (confirm && confirmController.text != pass) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Passphrases don\'t match.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(sheetContext, pass);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    final passphrase = await _askPassphrase(
      title: 'Protect your backup',
      subtitle:
          'The backup is encrypted with this passphrase. Without it the '
          'file can\'t be opened — including by you, so keep it safe.',
      buttonLabel: 'Create encrypted backup',
      confirm: true,
    );
    if (passphrase == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await BackupService().export(passphrase);
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      ref.read(appLockProvider.notifier).suppressAutoLock();
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'application/octet-stream',
                name: 'vault-backup-$stamp.aivault',
              ),
            ],
            text: 'AI Form & Vault encrypted backup',
          ),
        );
      } finally {
        ref.read(appLockProvider.notifier).resumeAutoLock();
      }
    } catch (_) {
      _toast('Backup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    ref.read(appLockProvider.notifier).suppressAutoLock();
    Uint8List? data;
    try {
      final file = await openFile();
      if (file != null) data = await file.readAsBytes();
    } finally {
      ref.read(appLockProvider.notifier).resumeAutoLock();
    }
    if (data == null) return;

    final passphrase = await _askPassphrase(
      title: 'Unlock backup',
      subtitle: 'Enter the passphrase this backup was created with.',
      buttonLabel: 'Restore',
    );
    if (passphrase == null) return;

    setState(() => _busy = true);
    try {
      final result = await BackupService().restore(data, passphrase);
      await ref.read(documentsProvider.notifier).refresh();
      await ref.read(identityGraphProvider.notifier).refresh();
      _toast(
        'Restored ${result.documents} document${result.documents == 1 ? '' : 's'}.',
      );
    } on BackupException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not read that backup file.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          onTap: _busy ? null : _export,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.upload_file_outlined,
                        size: 19,
                        color: AppColors.textPrimary,
                      ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export encrypted backup',
                        style: AppTextStyles.itemTitle),
                    const Gap(2),
                    Text(
                      'Passphrase-protected file you can store anywhere',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
        const Gap(10),
        AppCard(
          onTap: _busy ? null : _restore,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_backup_restore_rounded,
                  size: 19,
                  color: AppColors.textPrimary,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Restore from backup', style: AppTextStyles.itemTitle),
                    const Gap(2),
                    Text(
                      'Merge a .aivault file into this vault',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
