import 'dart:async';

import 'package:buspilot_rider/src/push/push_service.dart';

/// Push that is available; the OS permission is [osAllowed] (true like
/// Android 12 and older, where notifications are on by default).
class FakePush implements PushService {
  FakePush({this.osAllowed = true});

  bool osAllowed;
  int permissionRequests = 0;
  int tokenCalls = 0;
  int unregisters = 0;
  final _refresh = StreamController<String>.broadcast();

  @override
  bool get available => true;

  @override
  Future<bool> isAllowed() async => osAllowed;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    osAllowed = true;
    return true;
  }

  @override
  Future<String?> token() async {
    tokenCalls++;
    return osAllowed ? 'fid-123' : null;
  }

  @override
  Stream<String> get tokenRefresh => _refresh.stream;

  @override
  Future<void> unregister() async => unregisters++;
}
