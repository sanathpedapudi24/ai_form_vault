import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/document_model.dart';
import 'search_service.dart';

/// Local expiry reminders — a document with an expiry date gets
/// notifications 90, 30, and 7 days before it lapses (only the ones still
/// in the future when scheduled). Entirely on-device; no network involved.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'expiry_reminders';

  /// Days-before-expiry checkpoints. Order matters: the index is part of
  /// each notification's stable ID.
  static const reminderDays = [90, 30, 7];

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {
      // Fall back to UTC — reminders fire a few hours off, not never.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  /// Asks for notification permission (Android 13+ / iOS). Safe to call
  /// repeatedly; returns whether notifications are permitted.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true) ?? false;
    }
    return false;
  }

  /// Schedules reminders for [doc] if it has a parseable future expiry
  /// date. Replaces any previously scheduled reminders for this document.
  Future<void> scheduleForDocument(DocumentModel doc) async {
    await init();
    await cancelForDocument(doc.id);

    final expiryField = doc.fieldByKey(FactKeys.expiryDate);
    if (expiryField == null) return;
    final expiry = SearchService.parseFlexibleDate(expiryField.value);
    if (expiry == null) return;

    for (var i = 0; i < reminderDays.length; i++) {
      final days = reminderDays[i];
      final when = DateTime(expiry.year, expiry.month, expiry.day, 10)
          .subtract(Duration(days: days));
      if (when.isBefore(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        id: _notificationId(doc.id, i),
        title: '${doc.displayTitle} expires in $days days',
        body: 'Expires on ${expiryField.value}. Tap to open your vault.',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Document expiry reminders',
            channelDescription:
                'Reminders before your stored documents expire',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact keeps us off Android 12+'s exact-alarm special permission;
        // a reminder that's minutes late is fine at a 7-day horizon.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelForDocument(String docId) async {
    await init();
    for (var i = 0; i < reminderDays.length; i++) {
      await _plugin.cancel(id: _notificationId(docId, i));
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Re-registers reminders for every document (used when the user toggles
  /// reminders back on).
  Future<void> rescheduleAll(List<DocumentModel> docs) async {
    for (final doc in docs) {
      await scheduleForDocument(doc);
    }
  }

  /// Stable per-document, per-checkpoint ID. Truncated hash keeps it inside
  /// the 32-bit int notification IDs require.
  int _notificationId(String docId, int index) =>
      (docId.hashCode & 0x7FFFFF) * 10 + index;
}
