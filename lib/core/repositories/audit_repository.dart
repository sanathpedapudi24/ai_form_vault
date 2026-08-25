import '../db/app_database.dart';

/// Minimal append-only audit log. One method: [log].
/// Stores events in the encrypted database — never leaves the device.
class AuditRepository {
  const AuditRepository();

  Future<void> log({
    required String action,
    String targetType = '',
    String targetId = '',
    String detail = '',
  }) async {
    final db = await AppDatabase.instance;
    await db.insert('audit_events', {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'detail': detail,
    });
  }
}
