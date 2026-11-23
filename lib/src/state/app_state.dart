import 'dart:async';


import 'package:flutter/widgets.dart';

import '../data/api.dart';
import '../data/arrivals.dart';
import '../data/models.dart';
import '../push/push_service.dart';
import 'local_store.dart';

/// Languages the app is translated into.
const supportedLanguages = ['ja', 'en', 'de'];

enum StartupState { loading, chooseLanguage, ready, offlineNoData }

/// App-wide state. State management is plain [ChangeNotifier] provided through
/// [AppScope]: the app has one shared state (the device's catalog and live
/// trips) and a handful of screens, so no framework is needed.
class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.store,
    this.push = const NoPushService(),
    LiveSource? live,
    DateTime Function()? clock,
    String Function()? phoneLanguage,
    this.platform = 'android',
  }) : live = live ?? api,
       clock = clock ?? DateTime.now,
       _phoneLanguage = phoneLanguage ?? _systemLanguage;

  final BuspilotApi api;

  /// Trip progress, ETAs and bus positions (Supabase now, the engine's Live
  /// API later).
  final LiveSource live;
  final LocalStore store;
  final PushService push;
  final DateTime Function() clock;
  final String Function() _phoneLanguage;

  /// "ios" or "android" (device.platform).
  final String platform;

  StartupState startup = StartupState.loading;
  Catalog catalog = Catalog.empty();
  List<TripInstance> instances = const [];

  /// When [catalog] and [instances] were fetched from the server.
  DateTime? fetchedAt;

  /// The last refresh failed for lack of network; data is from the cache.
  bool offline = false;

  /// The last refresh failed on the server side; data is from the cache.
  bool serverError = false;
  bool refreshing = false;
  StreamSubscription<String>? _tokenSub;

  static String _systemLanguage() =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;

  /// The chosen language, or null to follow the phone.
  String? get chosenLanguage => store.language;

  /// The language in use: the chosen one, else the phone's if supported,
  /// else English.
  String get language {
    final chosen = store.language;
    if (chosen != null) return chosen;
    final phone = _phoneLanguage();
    return supportedLanguages.contains(phone) ? phone : 'en';
  }

  Future<void> setLanguage(String? value) async {
    await store.setLanguage(value);
    notifyListeners();
    if (startup == StartupState.ready) unawaited(_touchDevice(force: true));
  }

  Future<void> start() async {
    final cached = store.readCache();
    if (cached != null) {
      catalog = Catalog(cached.catalog);
      instances = cached.instances.map(TripInstance.new).toList();
      fetchedAt = cached.fetchedAt;
    }
    if (!store.onboarded) {
      startup = StartupState.chooseLanguage;
      notifyListeners();
      return;
    }
    await _connect(hasCache: cached != null);
  }

  /// First start: the language is chosen.
  Future<void> finishOnboarding(String? languageCode) async {
    await store.setLanguage(languageCode);
    await store.setOnboarded();
    startup = StartupState.loading;
    notifyListeners();
    await _connect(hasCache: false);
  }

  Future<void> _connect({required bool hasCache}) async {
    try {
      await api.ensureSignedIn();
      await _touchDevice(force: true);
      await refresh();
      // Nothing loaded and nothing cached: say so rather than showing an
      // empty home.
      startup = fetchedAt == null ? StartupState.offlineNoData : StartupState.ready;
      if (startup == StartupState.ready && store.pushOptedIn) _listenForPushTokens();
    } catch (e) {
      // Offline, or the server refused (5xx, auth): show the cache if there
      // is one, else a retry screen.
      if (e is! OfflineException) debugPrint('Start failed: $e');
      offline = e is OfflineException;
      serverError = !offline;
      startup = hasCache ? StartupState.ready : StartupState.offlineNoData;
    }
    notifyListeners();
  }

  /// Retry after starting without network.
  Future<void> retry() async {
    startup = StartupState.loading;
    notifyListeners();
    await _connect(hasCache: store.readCache() != null);
  }

  /// Keeps `device.last_seen_at` fresh: on every start and at most twice a
  /// day while the app is used.
  Future<void> _touchDevice({bool force = false}) async {
    final last = store.deviceTouchedAt;
    final now = clock();
    if (!force && last != null && now.difference(last) < const Duration(hours: 12)) {
      return;
    }
    try {
      await api.touchDevice(platform: platform, language: language);
      await store.setDeviceTouchedAt(now);
    } catch (e) {
      // Next time.
      if (e is! OfflineException) debugPrint('Device update failed: $e');
    }
  }

  /// Registers for push. Only after the user opted in (the explanation
  /// before the permission prompt), whatever the OS permission says: on
  /// Android 12 and older notifications are allowed by default.
  void _listenForPushTokens() {
    if (!store.pushOptedIn) return;
    _tokenSub ??= push.tokenRefresh.listen((t) async {
      try {
        await api.setPushToken(t);
      } catch (e) {
        // Registered again on the next start.
        debugPrint('Push token not stored: $e');
      }
    });
    unawaited(() async {
      final token = await push.token();
      if (token != null) {
        try {
          await api.setPushToken(token);
        } catch (e) {
          // Registered again on the next start.
          debugPrint('Push token not stored: $e');
        }
      }
    }());
  }

  /// The app came back to the foreground.
  Future<void> resumed() async {
    if (startup != StartupState.ready) return;
    await _touchDevice();
    await refresh();
  }

  Future<void>? _inflight;
  bool _again = false;

  /// Reloads the catalog and today's trips. Keeps the old data when that
  /// fails. A call during a running refresh runs once more afterwards (so a
  /// change just made is never missed) and completes with it.
  Future<void> refresh() {
    if (_inflight != null) {
      _again = true;
      return _inflight!;
    }
    return _inflight = () async {
      try {
        do {
          _again = false;
          await _refreshOnce();
        } while (_again);
      } finally {
        _inflight = null;
      }
    }();
  }

  /// Bumped by [deleteMyData]: a refresh that started before must not write
  /// the deleted device's data back.
  int _generation = 0;

  Future<void> _refreshOnce() async {
    final generation = _generation;
    refreshing = true;
    notifyListeners();
    try {
      final catalogJson = visibleCatalog(await api.fetchCatalog());
      final next = Catalog(catalogJson);
      final dates = {
        for (final op in next.operators)
          formatDate(serviceDay(locationOf(op), clock())),
      }.toList();
      final instanceJson = await live.fetchTripInstances(
        routeIds: [for (final r in next.routes) r.id],
        serviceDates: dates,
      );
      if (generation != _generation) return;
      catalog = next;
      instances = instanceJson.map(TripInstance.new).toList();
      fetchedAt = clock();
      offline = false;
      serverError = false;
      await store.writeCache(catalogJson, instanceJson, fetchedAt!);
    } on OfflineException {
      offline = true;
      serverError = false;
    } catch (e) {
      debugPrint('Refresh failed: $e');
      serverError = true;
      offline = false;
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<RedeemResult> redeem(String code) async {
    final result = await api.redeemInviteCode(code);
    if (result.status == RedeemStatus.joined ||
        result.status == RedeemStatus.alreadyMember) {
      await refresh();
    }
    return result;
  }

  /// Follows a stop or changes its alert settings. Returns true when this
  /// was a new follow (time to ask for notification permission).
  Future<bool> saveSubscription(Subscription s) async {
    final isNew = s.id == null;
    await api.saveSubscription(s);
    await refresh();
    return isNew;
  }

  /// Whether to explain push and ask: push works in this build and the user
  /// has not opted in yet.
  bool get shouldOfferPush => push.available && !store.pushOptedIn;

  /// The user agreed after the explanation: ask the OS, then register.
  Future<void> enablePush() async {
    await store.setPushOptedIn();
    if (await push.requestPermission()) _listenForPushTokens();
  }

  Future<void> unfollow(Subscription s) async {
    if (s.id != null) await api.deleteSubscription(s.id!);
    await refresh();
  }

  Future<void> leaveOperator(String operatorId) async {
    await api.leaveOperator(operatorId);
    await refresh();
  }

  /// Deletes the device on the server and everything on the phone, then
  /// starts over.
  Future<void> deleteMyData() async {
    // Let a running refresh finish; anything still in flight afterwards is
    // discarded through the generation.
    await _inflight;
    await api.deleteMyData();
    _generation++;
    await _tokenSub?.cancel();
    _tokenSub = null;
    await push.unregister();
    await store.clear();
    catalog = Catalog.empty();
    instances = const [];
    fetchedAt = null;
    startup = StartupState.chooseLanguage;
    notifyListeners();
  }

  /// Number of posts published after the news screen was last opened.
  int get unreadPosts {
    final read = store.newsReadAt;
    return catalog.posts
        .where((p) => read == null || p.publishedAt.isAfter(read))
        .length;
  }

  Future<void> markNewsRead() async {
    await store.setNewsReadAt(clock());
    notifyListeners();
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }
}

/// Provides [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Without rebuilding when the state changes (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
