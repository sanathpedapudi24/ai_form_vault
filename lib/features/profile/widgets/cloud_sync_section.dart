import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/document_provider.dart';
import '../../../core/providers/person_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';

/// Encrypted Firestore backup/restore, keyed to the signed-in account.
class CloudSyncSection extends ConsumerStatefulWidget {
  const CloudSyncSection({super.key});

  @override
  ConsumerState<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<CloudSyncSection> {
  final _sync = CloudSyncService();
  bool _busy = false;
  DateTime? _lastBackup;
  bool _loadedTime = false;

  @override
  void initState() {
    super.initState();
    _refreshTime();
  }

  Future<void> _refreshTime() async {
    final t = await _sync.lastBackupTime();
    if (mounted) setState(() { _lastBackup = t; _loadedTime = true; });
  }

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<String?> _askPassphrase(String title, String subtitle,
      String button, {bool confirm = false}) {
    final c = TextEditingController();
    final c2 = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
              controller: c,
              autofocus: true,
              obscureText: true,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'Passphrase'),
            ),
            if (confirm) ...[
              const Gap(10),
              TextField(
                controller: c2,
                obscureText: true,
                style: AppTextStyles.body,
                decoration:
                    const InputDecoration(hintText: 'Confirm passphrase'),
              ),
            ],
            const Gap(16),
            PrimaryButton(
              label: button,
              onPressed: () {
                if (c.text.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Use at least 6 characters.')));
                  return;
                }
                if (confirm && c.text != c2.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Passphrases don\'t match.')));
                  return;
                }
                Navigator.pop(ctx, c.text);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backup() async {
    if (_busy) return;
    final pass = await _askPassphrase(
      'Back up to cloud',
      'Encrypted with this passphrase before it leaves your device. Only '
          'you can restore it — keep the passphrase safe.',
      'Encrypt and upload',
      confirm: true,
    );
    if (pass == null) return;
    setState(() => _busy = true);
    try {
      final when = await _sync.upload(pass);
      setState(() => _lastBackup = when);
      _toast('Vault backed up to your account.');
    } on CloudSyncException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Cloud backup failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final pass = await _askPassphrase(
      'Restore from cloud',
      'Enter the passphrase this cloud backup was created with.',
      'Download and restore',
    );
    if (pass == null) return;
    setState(() => _busy = true);
    try {
      final result = await _sync.restore(pass);
      await ref.read(documentsProvider.notifier).refresh();
      await ref.read(identityGraphProvider.notifier).refresh();
      _toast('Restored ${result.documents} '
          'document${result.documents == 1 ? '' : 's'} from cloud.');
    } on BackupException catch (e) {
      _toast(e.message);
    } on CloudSyncException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Cloud restore failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = !_loadedTime
        ? 'Encrypted backup tied to your account'
        : _lastBackup == null
            ? 'No cloud backup yet'
            : 'Last backup ${DateFormat('d MMM, h:mm a').format(_lastBackup!)}';

    return Column(
      children: [
        AppCard(
          onTap: _busy ? null : _backup,
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
                    : Icon(Icons.cloud_upload_outlined,
                        size: 19, color: AppColors.textPrimary),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Back up to cloud', style: AppTextStyles.itemTitle),
                    const Gap(2),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
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
                child: Icon(Icons.cloud_download_outlined,
                    size: 19, color: AppColors.textPrimary),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Restore from cloud', style: AppTextStyles.itemTitle),
                    const Gap(2),
                    Text('Pull your vault onto this device',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ],
    );
  }
}
