import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Small on-device store: settings and the last known state for offline use.
/// Nothing here leaves the phone.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _language = 'language';
  static const _onboarded = 'onboarded';
  static const _newsReadAt = 'news_read_at';
  static const _catalog = 'cache.catalog';
  static const _instances = 'cache.instances';
  static const _fetchedAt = 'cache.fetched_at';
  static const _deviceTouchedAt = 'device_touched_at';
  static const _pushOptedIn = 'push_opted_in';

  static const keys = {
    _language,
    _onboarded,
    _newsReadAt,
    _catalog,
    _instances,
    _fetchedAt,
    _deviceTouchedAt,
    _pushOptedIn,
  };

  static Future<LocalStore> open() async => LocalStore(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: keys),
    ),
  );

  /// "ja", "en", "de", or null to follow the phone.
  String? get language => _prefs.getString(_language);
  Future<void> setLanguage(String? value) => value == null
      ? _prefs.remove(_language)
      : _prefs.setString(_language, value);

  /// The language was chosen on first start.
  bool get onboarded => _prefs.getBool(_onboarded) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_onboarded, true);

  /// The user agreed to push notifications in the app's explanation.
  bool get pushOptedIn => _prefs.getBool(_pushOptedIn) ?? false;
  Future<void> setPushOptedIn() => _prefs.setBool(_pushOptedIn, true);

  DateTime? get newsReadAt => _time(_newsReadAt);
  Future<void> setNewsReadAt(DateTime t) =>
      _prefs.setString(_newsReadAt, t.toUtc().toIso8601String());

  DateTime? get deviceTouchedAt => _time(_deviceTouchedAt);
  Future<void> setDeviceTouchedAt(DateTime t) =>
      _prefs.setString(_deviceTouchedAt, t.toUtc().toIso8601String());

  DateTime? _time(String key) {
    final v = _prefs.getString(key);
    return v == null ? null : DateTime.tryParse(v);
  }

  /// The last catalog and trip instances, with when they were fetched.
  ({Json catalog, List<Json> instances, DateTime fetchedAt})? readCache() {
    final c = _prefs.getString(_catalog);
    final i = _prefs.getString(_instances);
    final at = _time(_fetchedAt);
    if (c == null || i == null || at == null) return null;
    try {
      return (
        catalog: (jsonDecode(c) as Map).cast<String, dynamic>(),
        instances: [
          for (final e in jsonDecode(i) as List) (e as Map).cast<String, dynamic>(),
        ],
        fetchedAt: at,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> writeCache(Json catalog, List<Json> instances, DateTime at) async {
    await _prefs.setString(_catalog, jsonEncode(catalog));
    await _prefs.setString(_instances, jsonEncode(instances));
    await _prefs.setString(_fetchedAt, at.toUtc().toIso8601String());
  }

  /// Forgets everything (delete my data).
  Future<void> clear() => _prefs.clear();
}
