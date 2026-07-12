import 'package:sqflite_sqlcipher/sqflite.dart';

import '../db/app_database.dart';

/// Simple key-value settings stored inside the encrypted database.
class SettingsRepository {
  const SettingsRepository();

  static const legacyMigrationDone = 'legacy_migration_done';
  static const systemAutofillEnabled = 'system_autofill_enabled';
  static const userDisplayName = 'user_display_name';
  static const expiryRemindersEnabled = 'expiry_reminders_enabled';
  static const darkModeEnabled = 'dark_mode_enabled';
  static const onboardingDone = 'onboarding_done';

  Future<String?> get(String key) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    final db = await AppDatabase.instance;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final v = await get(key);
    return v == null ? defaultValue : v == 'true';
  }

  Future<void> setBool(String key, bool value) => set(key, value.toString());
}
