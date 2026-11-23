/// Push notifications. The engine sends them through FCM (APNs through FCM on
/// iOS); the app only registers its token in `device.push_token`.
///
/// The FCM implementation (firebase_messaging) needs a Firebase project and
/// is a follow-up. Until then [NoPushService] is used and no token is stored.
abstract class PushService {
  /// Asks the user for permission to show notifications. Called after the
  /// user follows a stop, never on first start.
  Future<bool> requestPermission();

  /// The current token, or null when push is not available.
  Future<String?> token();

  /// New tokens after a refresh.
  Stream<String> get tokenRefresh;
}

class NoPushService implements PushService {
  const NoPushService();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();
}
