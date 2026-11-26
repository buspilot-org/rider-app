import 'dart:async';

import 'package:buspilot_rider/src/data/api.dart';
import 'package:buspilot_rider/src/data/ewkb.dart';
import 'package:buspilot_rider/src/data/models.dart';

/// Fixed ids, as in the server's seed.
const opId = 'd0000000-0000-4000-8000-000000000001';
const routeId = 'd0000000-0000-4000-8000-000000000101';
const patternId = 'd0000000-0000-4000-8000-000000000301';
const calendarId = 'd0000000-0000-4000-8000-000000000501';
const trip0730 = 'd0000000-0000-4000-8000-000000000801';
const trip0810 = 'd0000000-0000-4000-8000-000000000802';
const demoCode = 'DEMO-KOBE-2026';

/// The demo operator of the server seed: a loop that serves Kitano-zaka twice
/// (sequence 2 and 5), trips at 07:30 and 08:10 on school days.
Json demoCatalog({List<Json> subscriptions = const [], bool member = true}) => {
  // What the server returns: routes from rpc/my_routes (the operator's
  // routes for members; for others, routes they follow), general posts for
  // members only. The fake has one route, so a non-member sees it only
  // while following a stop on it.
  'operators': [
    {
      'id': opId,
      'name': {'en': 'Kitano Demo International School', 'ja': '北野デモ国際学校'},
      'timezone': 'Asia/Tokyo',
      'languages': ['en', 'ja', 'de'],
      'branding': {'color': '1E6FD9'},
      'default_visibility': 'invited_eta',
      'operator_link': [
        {
          'id': 'l1',
          'label': {'en': 'School office', 'ja': '学校事務室'},
          'url': 'mailto:office@example.org',
          'sort_order': 1,
        },
      ],
    },
  ],
  'routes': [
    if (member || subscriptions.isNotEmpty) {
      'id': routeId,
      'operator_id': opId,
      'name': {'en': 'Morning route A', 'ja': '朝便A'},
      'short_name': 'A',
      'color': '1E6FD9',
      'text_color': 'FFFFFF',
      'visibility': null,
      'sort_order': 0,
      'trip_pattern': [
        {
          'id': patternId,
          'name': 'Morning loop',
          'shape_id': null,
          'pattern_stop': [
            _ps(1, 's1', 0, 'Shin-Kobe Station', '新神戸駅'),
            _ps(2, 's2', 300, 'Kitano-zaka', '北野坂'),
            _ps(3, 's3', 540, 'Sannomiya', '三宮'),
            _ps(4, 's4', 900, 'Motomachi', '元町'),
            _ps(5, 's2', 1260, 'Kitano-zaka', '北野坂'),
            _ps(6, 's5', 1500, 'School', '学校'),
          ],
          'trip': [
            {'id': trip0730, 'start_time': 27000, 'service_calendar_id': calendarId},
            {'id': trip0810, 'start_time': 29400, 'service_calendar_id': calendarId},
          ],
        },
      ],
    },
  ],
  'audience_routes': [
    {'route_id': routeId, 'can_see_map': false},
  ],
  'calendars': [
    {
      'id': calendarId,
      'operator_id': opId,
      'name': 'School days',
      'weekdays': 31,
      'start_date': '2026-04-01',
      'end_date': '2027-03-31',
      'skip_national_holidays': true,
      'calendar_exception': [
        {'start_date': '2026-12-24', 'end_date': '2027-01-07', 'type': 'removed', 'reason': 'Winter break'},
      ],
    },
  ],
  'memberships': [
    if (member) {'id': 'm1', 'operator_id': opId, 'audience_id': 'a1', 'revoked_at': null},
  ],
  'subscriptions': subscriptions,
  'posts': [
    if (member)
      {
        'id': 'p1',
        'operator_id': opId,
        'route_id': null,
        'category': 'general',
        'title': {'en': 'Welcome to Buspilot', 'ja': 'Buspilot へようこそ'},
        'body': {'en': 'This is a demo operator.', 'ja': 'これはデモ用の事業者です。'},
        'published_at': '2026-11-23T00:00:00Z',
      },
  ],
};

/// A live trip with its own planned stops (no pattern): a tour of the demo
/// operator, stops s1 → s3 → s5.
Json liveTrip({
  String id = 'live-1',
  String status = 'planned',
  String serviceDate = '2026-11-23',
  String? visibleUntil = '2026-11-23T12:00:00Z',
  List<Json> events = const [],
  String? routeId,
}) => {
  'id': id,
  'operator_id': opId,
  'route_id': routeId,
  'pattern_id': null,
  'trip_id': null,
  'service_date': serviceDate,
  'kind': 'live',
  'status': status,
  'off_route_since': null,
  'title': {'en': 'Museum tour', 'ja': '博物館見学'},
  'visible_until': visibleUntil,
  'trip_instance_stop': [
    _planned(1, 's1', '2026-11-23T01:00:00Z', 'Shin-Kobe Station', '新神戸駅'),
    _planned(2, 's3', '2026-11-23T01:20:00Z', 'Sannomiya', '三宮'),
    _planned(3, 's5', '2026-11-23T01:45:00Z', 'School', '学校'),
  ],
  'stop_event': events,
};

Json _planned(int seq, String stopId, String arrival, String en, String ja) => {
  'stop_sequence': seq,
  'stop_id': stopId,
  'planned_arrival': arrival,
  'planned_departure': null,
  'stop': {
    'name': {'en': en, 'ja': ja},
  },
};

Json _ps(int seq, String stopId, int offset, String en, String ja) => {
  'stop_sequence': seq,
  'stop_id': stopId,
  'arrival_offset': offset,
  'stop': {
    'name': {'en': en, 'ja': ja},
  },
};

/// A trip instance of the demo pattern with stop events.
Json instance({
  required String id,
  required String tripId,
  required String serviceDate,
  required String status,
  List<Json> events = const [],
}) => {
  'id': id,
  'trip_id': tripId,
  'pattern_id': patternId,
  'route_id': routeId,
  'service_date': serviceDate,
  'kind': 'scheduled',
  'status': status,
  'off_route_since': null,
  'stop_event': events,
};

Json event(int seq, String state, {DateTime? eta, DateTime? arrived, DateTime? departed}) => {
  'stop_sequence': seq,
  'state': state,
  'eta': eta?.toUtc().toIso8601String(),
  'arrived_at': arrived?.toUtc().toIso8601String(),
  'departed_at': departed?.toUtc().toIso8601String(),
  'passed_at': null,
};

/// In-memory backend. Starts without membership until [demoCode] is redeemed
/// (unless [joined]).
class FakeApi implements BuspilotApi {
  FakeApi({bool joined = false, List<Json>? instances}) : _member = joined {
    this.instances = instances ?? [];
  }

  bool _member;
  bool offline = false;
  late List<Json> instances;

  /// Live trips with planned stops (fetchLiveTrips).
  List<Json> liveTrips = [];
  final subscriptions = <Json>[];
  final calls = <String>[];
  String? deviceLanguage;
  bool deviceDeleted = false;

  /// device.push_token on the server (the engine may clear it).
  String? pushToken;

  /// National holidays ("2026-11-23" → name). None by default, so tests on
  /// Monday 2026-11-23 (a holiday) keep their buses.
  Map<String, Json> holidays = {};

  /// Posts the server returns (null: the demo catalog's).
  List<Json>? posts;

  /// stop id → [lng, lat] the server returns from stop_location.
  Map<String, LngLat> stopLocations = {};

  /// Thrown by every call, like a server error (not offline).
  Object? serverError;

  void _check() {
    if (offline) throw const OfflineException('fake offline');
    if (serverError != null) throw serverError!;
  }

  /// Extra rows RLS would return from `operator` and `service_calendar`:
  /// another operator with a public route (not in rpc/my_routes).
  bool withForeignPublicRoute = false;

  @override
  Future<String> ensureSignedIn() async {
    _check();
    calls.add('signIn');
    return 'user-1';
  }

  @override
  Future<bool> touchDevice({required String platform, required String language}) async {
    _check();
    calls.add('touchDevice');
    deviceLanguage = language;
    return pushToken != null;
  }

  @override
  Future<void> setPushToken(String? token) async {
    calls.add('pushToken:$token');
    pushToken = token;
  }

  /// When set, fetchCatalog waits for it (to test overlapping refreshes).
  Completer<void>? catalogGate;
  int catalogCalls = 0;

  @override
  Future<RedeemResult> redeemInviteCode(String code) async {
    _check();
    calls.add('redeem:$code');
    final normal = code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (normal != demoCode.replaceAll('-', '')) {
      return const RedeemResult(RedeemStatus.invalid);
    }
    if (_member) return const RedeemResult(RedeemStatus.alreadyMember, operatorId: opId);
    _member = true;
    return const RedeemResult(RedeemStatus.joined, operatorId: opId);
  }

  DateTime? catalogFrom;

  @override
  Future<Json> fetchCatalog({required DateTime from, required DateTime to}) async {
    catalogCalls++;
    catalogFrom = from;
    await catalogGate?.future;
    _check();
    calls.add('catalog');
    final json = demoCatalog(subscriptions: List.of(subscriptions), member: _member);
    if (posts != null && _member) json['posts'] = List.of(posts!);
    if (withForeignPublicRoute) {
      (json['operators'] as List).add({
        'id': 'hotel',
        'name': {'en': 'Harbour Hotel'},
        'timezone': 'Asia/Tokyo',
        'default_visibility': 'public',
      });
      (json['calendars'] as List).add({
        'id': 'hotel-daily',
        'operator_id': 'hotel',
        'weekdays': 127,
        'start_date': '2026-01-01',
        'end_date': '2027-12-31',
        'skip_national_holidays': false,
      });
    }
    // rpc/service_days for the operators of the device's routes, and
    // national_holiday, as the server computes them.
    final routeOps = {for (final r in json['routes'] as List) (r as Map)['operator_id']};
    final serviceDays = <Json>[];
    for (final c in (json['calendars'] as List).cast<Json>()) {
      if (!routeOps.contains(c['operator_id'])) continue;
      final cal = ServiceCalendar(c);
      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        final key = formatDate(d);
        final added = cal.exceptions.any((e) => e.added && e.covers(d));
        final holiday = holidays.containsKey(key) && cal.skipNationalHolidays && !added;
        if (cal.runsOn(d) && !holiday) {
          serviceDays.add({'calendar_id': cal.id, 'service_date': key});
        }
      }
    }
    json['service_days'] = serviceDays;
    json['service_days_from'] = formatDate(from);
    json['service_days_to'] = formatDate(to);
    json['holidays'] = [
      for (final e in holidays.entries)
        if (!parseDate(e.key).isBefore(from) && !parseDate(e.key).isAfter(to))
          {'date': e.key, 'name': e.value},
    ];
    return json;
  }

  @override
  Future<List<Json>> fetchLiveTrips({
    required List<String> operatorIds,
    required List<String> serviceDates,
  }) async {
    _check();
    if (!_member) return const [];
    return liveTrips.where((t) => operatorIds.contains(t['operator_id'])).toList();
  }

  @override
  Future<List<Json>> fetchTripInstances({
    required List<String> routeIds,
    required List<String> serviceDates,
  }) async {
    _check();
    return instances
        .where((i) => routeIds.contains(i['route_id']) && serviceDates.contains(i['service_date']))
        .toList();
  }

  @override
  Future<MapData> fetchMapData({
    required String? shapeId,
    required List<String> stopIds,
  }) async {
    _check();
    calls.add('mapData:${stopIds.join(',')}');
    return MapData(stops: {
      for (final id in stopIds) id: ?stopLocations[id],
    });
  }

  @override
  Future<VehiclePosition?> fetchVehicle(String tripInstanceId) async => null;

  @override
  Future<void> saveSubscription(Subscription s) async {
    _check();
    calls.add('saveSubscription:${s.tripInstanceId ?? ''}${s.stopSequence}');
    subscriptions.removeWhere(
      (e) =>
          e['pattern_id'] == s.patternId &&
          e['trip_instance_id'] == s.tripInstanceId &&
          e['stop_sequence'] == s.stopSequence,
    );
    subscriptions.add({
      ...s.toJson(),
      'id': s.id ?? 'sub-${s.tripInstanceId ?? ''}${s.stopSequence}',
    });
  }

  @override
  Future<void> deleteSubscription(String id) async {
    _check();
    subscriptions.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<void> leaveOperator(String operatorId) async {
    _check();
    calls.add('leave:$operatorId');
    _member = false;
    subscriptions.clear();
  }

  @override
  Future<void> deleteMyData() async {
    _check();
    calls.add('deleteMyDevice');
    deviceDeleted = true;
    pushToken = null;
    _member = false;
    subscriptions.clear();
  }
}
