import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Reminders {
  final plugin = FlutterLocalNotificationsPlugin();
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'appointments_brand_v2',
      'Appointments',
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('brand_logo'),
      color: Color(0xff1E293B),
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  Future<void> init() async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> request() async {
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true, badge: true);
  }

  Future<void> test() async {
    await init();
    await request();
    await plugin.show(
      2147483000,
      'Dr. Ahmad Tarraf',
      'تم تفعيل إشعارات العيادة • Clinic notifications enabled',
      details,
    );
  }

  Future<void> schedule(int id, DateTime at) async {
    if (at.isBefore(DateTime.now())) return;
    await plugin.zonedSchedule(
      id,
      'Dr. Ahmad Tarraf',
      'Appointment reminder / تذكير بموعد',
      tz.TZDateTime.from(at, tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) => plugin.cancel(id);
  Future<void> cancelAll() => plugin.cancelAll();
}
