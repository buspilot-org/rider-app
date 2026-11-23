import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'push_service.dart';

/// Push through Firebase Cloud Messaging (APNs through FCM on iOS, once iOS
/// is configured). The app only registers the token; the engine sends.
///
/// `device.push_token` holds the Firebase Installation ID from
/// [FirebaseMessaging.onRegistered].
class FcmPushService implements PushService {
  FcmPushService._(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  bool get available => true;

  /// Initialises Firebase. Returns [NoPushService] when Firebase is not
  /// configured for this platform or fails to start, so the app keeps
  /// working without push.
  static Future<PushService> create() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return FcmPushService._(FirebaseMessaging.instance);
    } catch (e) {
      debugPrint('Push disabled: Firebase did not start ($e)');
      return const NoPushService();
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('Push permission request failed ($e)');
      return false;
    }
  }

  @override
  Future<bool> isAllowed() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> unregister() async {
    try {
      await _messaging.unregister();
    } catch (e) {
      debugPrint('Push unregister failed ($e)');
    }
  }

  @override
  Future<String?> token() async {
    try {
      // Only once the user allowed notifications (asked after following a
      // stop): no token, no device identifier on the server.
      if (!await isAllowed()) return null;
      // firebase_messaging 17: register() and onRegistered deliver the
      // Firebase Installation ID (FID), the direct-send target for this app
      // instance, instead of the old FCM registration token.
      final id = _messaging.onRegistered.first.timeout(const Duration(seconds: 30));
      await _messaging.register();
      return await id;
    } catch (e) {
      // No Play services, no network, …: try again on the next start.
      debugPrint('Push token unavailable ($e)');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh =>
      _messaging.onRegistered.handleError((Object e) => debugPrint('Registration failed ($e)'));
}
