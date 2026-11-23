/// Push notifications. The engine sends them through FCM (APNs through FCM on
/// iOS); the app only registers its token in `device.push_token`.
///
/// [FcmPushService] on Android; [NoPushService] where Firebase is not
/// configured (iOS for now) or fails to start, so no token is stored.
abstract class PushService {
  /// Whether push works in this build (Firebase configured and started).
  bool get available;

  /// Asks the user for permission to show notifications. Called after the
  /// user follows a stop, never on first start.
  Future<bool> requestPermission();

  /// Whether notifications are already allowed by the OS.
  Future<bool> isAllowed();

  /// Removes this app instance's registration (delete my data).
  Future<void> unregister();

  /// The current token, or null when push is not available.
  Future<String?> token();

  /// New tokens after a refresh.
  Stream<String> get tokenRefresh;
}

class NoPushService implements PushService {
  const NoPushService();

  @override
  bool get available => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> isAllowed() async => false;

  @override
  Future<void> unregister() async {}

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();
}
