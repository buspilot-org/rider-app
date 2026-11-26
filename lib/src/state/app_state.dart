import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../config.dart';
import '../data/api.dart';
import '../data/arrivals.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../push/push_alert.dart';
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
    this.mapStyleUrl = AppConfig.mapStyleUrl,
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

  /// MapLibre style; empty: no maps in this build.
  final String mapStyleUrl;

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
    unawaited(_createChannels());
    // The engine writes notification texts in device.language.
    if (startup == StartupState.ready) unawaited(_touchDevice(force: true));
  }

  /// Android notification channels, named in the app's language. Only once
  /// the user opted in to push: before that nothing is sent to this phone.
  Future<void> _createChannels() async {
    if (!push.available || !store.pushOptedIn) return;
    final l = lookupAppLocalizations(Locale(language));
    await push.createChannels({
      arrivalAlertsChannel: l.channelArrivalAlerts,
      tripChangesChannel: l.channelTripChanges,
    });
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
    unawaited(_createChannels());
    await _connect(hasCache: cached != null);
  }

  /// First start: the language is chosen.
  Future<void> finishOnboarding(String? languageCode) async {
    await store.setLanguage(languageCode);
    await store.setOnboarded();
    unawaited(_createChannels());
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
      final hasToken = await api.touchDevice(platform: platform, language: language);
      await store.setDeviceTouchedAt(now);
      // The engine clears a token FCM rejected: register again. (On start
      // the app registers anyway once the catalog is loaded.)
      if (!hasToken && _tokenSub != null) unawaited(_registerPushToken());
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
    unawaited(_registerPushToken());
  }

  /// Registers with FCM and stores the current token.
  Future<void> _registerPushToken() async {
    final token = await push.token();
    if (token == null) return;
    try {
      await api.setPushToken(token);
    } catch (e) {
      // Registered again on the next start.
      debugPrint('Push token not stored: $e');
    }
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
      catalogJson.addAll(await _serviceDays(catalogJson));
      final next = Catalog(catalogJson);
      final dates = {
        for (final op in next.operators)
          formatDate(serviceDay(locationOf(op), clock())),
      }.toList();
      final results = await Future.wait([
        live.fetchTripInstances(
          routeIds: [for (final r in next.routes) r.id],
          serviceDates: dates,
        ),
        live.fetchLiveTrips(
          operatorIds: [for (final o in next.operators) o.id],
          serviceDates: dates,
        ),
      ]);
      final routeIds = {for (final r in next.routes) r.id};
      final members = next.memberOperatorIds;
      final seen = <String>{};
      final instanceJson = [
        ...results[0],
        // Live trips of joined operators, and of the device's (followed
        // public) routes; not every live trip a public route has.
        for (final t in results[1])
          if (members.contains(t['operator_id']) || routeIds.contains(t['route_id'])) t,
      ].where((t) => seen.add(t['id'] as String)).toList();
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

  /// Service days change rarely: reuse the last ones for the same range,
  /// operators and calendars (rules and exceptions, read with every refresh)
  /// for [_serviceDaysMaxAge], instead of loading 13 months of days with
  /// every 30-second poll. A calendar edit loads them again at once.
  static const _serviceDaysMaxAge = Duration(hours: 6);

  Future<Json> _serviceDays(Json catalogJson) async {
    final (from, to) = serviceDaysRange(clock());
    final operators = {
      for (final r in (catalogJson['routes'] as List? ?? const []))
        (r as Map)['operator_id'] as String,
    }.toList()..sort();
    final calendars = [
      for (final c in (catalogJson['calendars'] as List? ?? const []))
        (c as Map).cast<String, dynamic>(),
    ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final key = [
      formatDate(from),
      operators.join(','),
      _fnv1a(jsonEncode(calendars)),
    ].join('|');
    final old = catalog.json;
    final at = DateTime.tryParse(old['service_days_at'] as String? ?? '');
    if (at != null &&
        clock().difference(at) < _serviceDaysMaxAge &&
        !clock().isBefore(at) &&
        old['service_days_key'] == key) {
      return {
        for (final k in [
          'service_days',
          'holidays',
          'service_days_from',
          'service_days_to',
          'service_days_calendars',
          'service_days_key',
          'service_days_at',
        ])
          k: old[k],
      };
    }
    final days = await api.fetchServiceDays(operatorIds: operators, from: from, to: to);
    return {
      'service_days': days['service_days'] ?? const [],
      'holidays': days['holidays'] ?? const [],
      'service_days_from': formatDate(from),
      'service_days_to': formatDate(to),
      // Calendars the days were loaded for; others use their own rules.
      'service_days_calendars': [for (final c in calendars) c['id']],
      'service_days_key': key,
      'service_days_at': clock().toUtc().toIso8601String(),
    };
  }

  /// FNV-1a (64 bit) of [text]: a cache key that is stable across starts.
  static String _fnv1a(String text) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(text)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toUnsigned(64).toRadixString(16);
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
    unawaited(_createChannels());
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

  /// Live trips with their own planned stops that are still shown.
  List<TripInstance> get liveTrips {
    final now = clock();
    return [
      for (final i in instances)
        if (i.isStandaloneLive && i.visibleAt(now)) i,
    ];
  }

  TripInstance? liveTrip(String id) {
    for (final t in liveTrips) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Post categories the rider hid in the news list.
  Set<PostCategory> get hiddenCategories => store.hiddenCategories;

  Future<void> setCategoryHidden(PostCategory category, bool hidden) async {
    final next = {...store.hiddenCategories};
    hidden ? next.add(category) : next.remove(category);
    await store.setHiddenCategories(next);
    notifyListeners();
  }

  /// Posts to show: newest first, without hidden categories.
  List<Post> get shownPosts {
    final hidden = hiddenCategories;
    return [
      for (final p in catalog.posts)
        if (!hidden.contains(p.category)) p,
    ];
  }

  /// Number of shown posts published after the news screen was last opened.
  int get unreadPosts {
    final read = store.newsReadAt;
    return shownPosts
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

/// Dates to load service days for: from the first day of this month to 399
/// days later (`rpc/service_days` takes at most 400 days), in Japan's time
/// zone, where all operators are for now. Days outside the range fall back
/// to the calendar's own rules ([Catalog.runsOn]).
(DateTime, DateTime) serviceDaysRange(DateTime now) {
  final today = serviceDay(locationOf(null), now);
  final from = DateTime.utc(today.year, today.month);
  return (from, from.add(const Duration(days: 399)));
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
