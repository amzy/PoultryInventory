import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();

      await _local.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: ios,
        ),
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'poultry_inventory',
              'Poultry Inventory',
              description: 'Poultry Inventory notifications',
              importance: Importance.high,
            ),
          );

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessage.listen(_showForeground);
    }

    await registerToken();
    _messaging.onTokenRefresh.listen((_) => registerToken());
  }

  Future<void> registerToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb
            ? const String.fromEnvironment('FCM_WEB_VAPID_KEY')
            : null,
      );
      if (token == null || token.isEmpty) return;

      await _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(token.length > 120 ? token.substring(0, 120) : token)
          .set(
        {
          'token': token,
          'platform': kIsWeb
              ? 'web'
              : (Platform.isIOS ? 'ios' : 'android'),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'poultry_inventory',
          'Poultry Inventory',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
