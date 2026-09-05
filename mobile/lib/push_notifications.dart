import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushRegistration {
  const PushRegistration({this.token, this.platform, this.authorized = false});

  final String? token;
  final String? platform;
  final bool authorized;
}

/// Registers the installation with Firebase when the platform project files
/// are present. Missing Firebase configuration is reported as unavailable;
/// local workout reminders continue to work through the native timer bridge.
class PushNotificationRegistrar {
  const PushNotificationRegistrar();

  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

  Future<PushRegistration> register({
    Future<void> Function(RemoteMessage message)? onForegroundMessage,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const PushRegistration(authorized: true);
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) return const PushRegistration();
      final token = await messaging.getToken();
      if (onForegroundMessage != null && _foregroundSubscription == null) {
        _foregroundSubscription = FirebaseMessaging.onMessage.listen(
          onForegroundMessage,
        );
      }
      return PushRegistration(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        authorized: true,
      );
    } catch (_) {
      return const PushRegistration();
    }
  }

  Future<PushRegistration> unregister() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const PushRegistration(authorized: true);
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      await messaging.deleteToken();
      return PushRegistration(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        authorized: true,
      );
    } catch (_) {
      return const PushRegistration();
    }
  }
}
