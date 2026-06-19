import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alert.dart';

/// System notifications for fire alerts. Fires from [AlertStore.add] so users
/// see push-style alerts on the lock screen even when the app is backgrounded.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    if (_ready || kIsWeb) return;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(settings: initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _ready = true;
  }

  Future<void> showAlert(AppAlert a) async {
    if (kIsWeb) return;
    if (!_ready) await init();

    final isHigh = a.severity == AlertSeverity.high;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        isHigh ? 'fire_alerts_high' : 'fire_alerts',
        isHigh ? 'High Fire Alerts' : 'Fire Alerts',
        channelDescription:
            'Wildfire risk alerts from monitored zones (active and inactive).',
        importance: isHigh ? Importance.max : Importance.high,
        priority: isHigh ? Priority.max : Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        color: isHigh
            ? const Color.fromARGB(255, 186, 12, 12)
            : const Color.fromARGB(255, 255, 158, 24),
        ticker: a.title,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isHigh
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );

    await _plugin.show(
      id: a.id.hashCode,
      title: '${a.title} — ${a.zoneName}',
      body: a.subtitle,
      notificationDetails: details,
      payload: a.id,
    );
  }
}
