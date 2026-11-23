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
    DateTime Function()? clock,
    String Function()? phoneLanguage,
    this.platform = 'android',
  }) : clock = clock ?? DateTime.now,
       _phoneLanguage = phoneLanguage ?? _systemLanguage;

  final BuspilotApi api;
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
      startup = StartupState.ready;
      _listenForPushTokens();
    } on OfflineException {
      offline = true;
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
    } on OfflineException {
      // Next time.
    }
  }

  void _listenForPushTokens() {
    _tokenSub ??= push.tokenRefresh.listen((t) => api.setPushToken(t));
    unawaited(() async {
      final token = await push.token();
      if (token != null) {
        try {
          await api.setPushToken(token);
        } on OfflineException {
          // Registered again on the next start.
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

  /// Reloads the catalog and today's trips. Keeps the old data when offline.
  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      final catalogJson = await api.fetchCatalog();
      final next = Catalog(catalogJson);
      final dates = {
        for (final op in next.operators)
          formatDate(serviceDay(locationOf(op), clock())),
      }.toList();
      final instanceJson = await api.fetchTripInstances(
        routeIds: [for (final r in next.routes) r.id],
        serviceDates: dates,
      );
      catalog = next;
      instances = instanceJson.map(TripInstance.new).toList();
      fetchedAt = clock();
      offline = false;
      await store.writeCache(catalogJson, instanceJson, fetchedAt!);
    } on OfflineException {
      offline = true;
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
    if (isNew) {
      unawaited(() async {
        if (await push.requestPermission()) _listenForPushTokens();
      }());
    }
    return isNew;
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
    await api.deleteMyData();
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
