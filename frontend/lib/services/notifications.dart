import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notif = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await notif
      .initialize(const InitializationSettings(android: android, iOS: ios));

  for (final ch in [
    AndroidNotificationChannel(
      'nexus_detected',
      'Nexus Wake Word',
      description: 'Notificaciones cuando se detecta "nexus"',
      importance: Importance.high,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'nexus_service',
      'Nexus Service',
      description: 'Servicio de deteccion en segundo plano',
      importance: Importance.low,
      playSound: false,
    ),
  ]) {
    await notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(ch);
  }
}

Future<void> showDetectionNotification(double score) async {
  await notif.show(
    0,
    'Hey Nexus!',
    'Wake word detectado (${score.toStringAsFixed(2)})',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'nexus_detected',
        'Nexus Wake Word',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
