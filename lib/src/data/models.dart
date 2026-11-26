// Read models over the rows the API returns. They wrap the JSON as it comes
// from PostgREST, so the same JSON can be cached and read back offline.

typedef Json = Map<String, dynamic>;

/// A `date` column ("2026-12-24") as a UTC midnight, so dates compare
/// without time zone effects.
DateTime parseDate(String value) {
  final d = DateTime.parse(value);
  return DateTime.utc(d.year, d.month, d.day);
}

/// [day] as a UTC midnight date.
DateTime dateOnly(DateTime day) => DateTime.utc(day.year, day.month, day.day);

/// "2026-12-24".
String formatDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Translatable text: {"ja": "…", "en": "…"}.
class I18nText {
  const I18nText(this.values);

  factory I18nText.fromJson(Object? json) {
    if (json is Map) {
      return I18nText({
        for (final e in json.entries)
          if (e.value is String) e.key as String: e.value as String,
      });
    }
    return const I18nText({});
  }

  final Map<String, String> values;

  /// The text in [language], else English, else Japanese, else any.
  String resolve(String language) {
    if (values.isEmpty) return '';
    final base = language.split(RegExp('[-_]')).first;
    return values[language] ??
        values[base] ??
        values['en'] ??
        values['ja'] ??
        values.values.first;
  }

  /// Whether the text exists in [language] itself (no fallback).
  bool hasLanguage(String language) =>
      values.containsKey(language.split(RegExp('[-_]')).first);
}

enum RouteVisibility { public, invitedMap, invitedEta }

RouteVisibility? parseVisibility(Object? value) => switch (value) {
  'public' => RouteVisibility.public,
  'invited_map' => RouteVisibility.invitedMap,
  'invited_eta' => RouteVisibility.invitedEta,
  _ => null,
};

class OperatorLink {
  OperatorLink(this.json);
  final Json json;
  String get id => json['id'] as String;
  I18nText get label => I18nText.fromJson(json['label']);
  String get url => json['url'] as String;
  int get sortOrder => (json['sort_order'] as num?)?.toInt() ?? 0;
}

class Operator {
  Operator(this.json);
  final Json json;

  String get id => json['id'] as String;
  I18nText get name => I18nText.fromJson(json['name']);
  String get timezone => (json['timezone'] as String?) ?? 'Asia/Tokyo';
  RouteVisibility get defaultVisibility =>
      parseVisibility(json['default_visibility']) ?? RouteVisibility.invitedEta;
  Json get branding => (json['branding'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// Brand colour as RRGGBB, if set.
  String? get colorHex {
    final c = branding['color'];
    if (c is String && RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(c)) {
      return c.replaceFirst('#', '');
    }
    return null;
  }

  /// Logo URL as stored (`branding.logo_url`). Show it only through
  /// [brandingImageUrl], which allows the Buspilot Storage host only.
  String? get logoUrl => _string(branding['logo_url']);

  /// Cover image URL as stored (`branding.cover_url`); see [logoUrl].
  String? get coverUrl => _string(branding['cover_url']);

  static String? _string(Object? v) => v is String && v.isNotEmpty ? v : null;

  List<OperatorLink> get links {
    final list = [
      for (final l in (json['operator_link'] as List? ?? const []))
        OperatorLink((l as Map).cast<String, dynamic>()),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }
}

class PatternStop {
  PatternStop(this.json);
  final Json json;
  int get sequence => (json['stop_sequence'] as num).toInt();
  String get stopId => json['stop_id'] as String;
  int get arrivalOffset => (json['arrival_offset'] as num).toInt();
  I18nText get stopName =>
      I18nText.fromJson((json['stop'] as Map?)?['name']);
}

class Trip {
  Trip(this.json);
  final Json json;
  String get id => json['id'] as String;
  int get startTime => (json['start_time'] as num).toInt();
  String get calendarId => json['service_calendar_id'] as String;
  I18nText get headsign => I18nText.fromJson(json['headsign']);
}

class TripPattern {
  TripPattern(this.json);
  final Json json;
  String get id => json['id'] as String;
  String get name => (json['name'] as String?) ?? '';
  String? get shapeId => json['shape_id'] as String?;

  List<PatternStop> get stops => [
    for (final s in (json['pattern_stop'] as List? ?? const []))
      PatternStop((s as Map).cast<String, dynamic>()),
  ]..sort((a, b) => a.sequence.compareTo(b.sequence));

  List<Trip> get trips => [
    for (final t in (json['trip'] as List? ?? const []))
      Trip((t as Map).cast<String, dynamic>()),
  ]..sort((a, b) => a.startTime.compareTo(b.startTime));

  PatternStop? stopAt(int sequence) {
    for (final s in stops) {
      if (s.sequence == sequence) return s;
    }
    return null;
  }
}

class BusRoute {
  BusRoute(this.json);
  final Json json;
  String get id => json['id'] as String;
  String get operatorId => json['operator_id'] as String;
  I18nText get name => I18nText.fromJson(json['name']);
  String? get shortName => json['short_name'] as String?;
  String? get color => json['color'] as String?;
  String? get textColor => json['text_color'] as String?;
  RouteVisibility? get visibility => parseVisibility(json['visibility']);
  int get sortOrder => (json['sort_order'] as num?)?.toInt() ?? 0;

  List<TripPattern> get patterns => [
    for (final p in (json['trip_pattern'] as List? ?? const []))
      TripPattern((p as Map).cast<String, dynamic>()),
  ];
}

class CalendarException {
  CalendarException(this.json);
  final Json json;
  DateTime get start => parseDate(json['start_date'] as String);
  DateTime get end => parseDate(json['end_date'] as String);
  bool get added => json['type'] == 'added';
  String? get reason => json['reason'] as String?;
  bool covers(DateTime day) => !day.isBefore(start) && !day.isAfter(end);
}

class ServiceCalendar {
  ServiceCalendar(this.json);
  final Json json;
  String get id => json['id'] as String;
  String get operatorId => json['operator_id'] as String;
  String get name => (json['name'] as String?) ?? '';

  /// Bit 0 = Monday … bit 6 = Sunday.
  int get weekdays => (json['weekdays'] as num).toInt();
  DateTime get start => parseDate(json['start_date'] as String);
  DateTime get end => parseDate(json['end_date'] as String);
  bool get skipNationalHolidays => json['skip_national_holidays'] == true;

  List<CalendarException> get exceptions => [
    for (final e in (json['calendar_exception'] as List? ?? const []))
      CalendarException((e as Map).cast<String, dynamic>()),
  ];

  /// Whether the calendar's weekdays, dates and exceptions include [day] (a
  /// date; time is ignored). National holidays are not applied here: use
  /// [Catalog.runsOn], which has the server's service days.
  bool runsOn(DateTime day) {
    final d = dateOnly(day);
    for (final e in exceptions) {
      if (e.covers(d)) return e.added;
    }
    if (d.isBefore(start) || d.isAfter(end)) return false;
    return weekdays & (1 << (d.weekday - 1)) != 0;
  }
}

class Membership {
  Membership(this.json);
  final Json json;
  String get id => json['id'] as String;
  String get operatorId => json['operator_id'] as String;
  bool get active => json['revoked_at'] == null;
}

enum AlertTrigger { minutes, stops }

/// A followed stop: a stop of a pattern (every trip of it, [patternId]) or a
/// planned stop of one live trip ([tripInstanceId]). Exactly one is set.
class Subscription {
  Subscription({
    this.id,
    required this.operatorId,
    this.patternId,
    this.tripInstanceId,
    required this.stopSequence,
    this.trigger = AlertTrigger.minutes,
    this.triggerValue = 5,
    this.notifyPassed = false,
    this.mutedUntil,
  });

  factory Subscription.fromJson(Json json) => Subscription(
    id: json['id'] as String?,
    operatorId: json['operator_id'] as String,
    patternId: json['pattern_id'] as String?,
    tripInstanceId: json['trip_instance_id'] as String?,
    stopSequence: (json['stop_sequence'] as num).toInt(),
    trigger: json['trigger'] == 'stops' ? AlertTrigger.stops : AlertTrigger.minutes,
    triggerValue: (json['trigger_value'] as num?)?.toInt() ?? 5,
    notifyPassed: json['notify_passed'] == true,
    mutedUntil: json['muted_until'] == null
        ? null
        : DateTime.parse(json['muted_until'] as String),
  );

  final String? id;
  final String operatorId;
  final String? patternId;
  final String? tripInstanceId;
  final int stopSequence;

  bool get isLive => tripInstanceId != null;
  final AlertTrigger trigger;
  final int triggerValue;
  final bool notifyPassed;
  final DateTime? mutedUntil;

  bool isMuted(DateTime now) => mutedUntil != null && mutedUntil!.isAfter(now);

  Json toJson() => {
    if (id != null) 'id': id,
    'operator_id': operatorId,
    'pattern_id': patternId,
    'trip_instance_id': tripInstanceId,
    'stop_sequence': stopSequence,
    'trigger': trigger.name,
    'trigger_value': triggerValue,
    'notify_passed': notifyPassed,
    'muted_until': mutedUntil?.toUtc().toIso8601String(),
  };

  Subscription copyWith({
    AlertTrigger? trigger,
    int? triggerValue,
    bool? notifyPassed,
    DateTime? mutedUntil,
    bool clearMute = false,
  }) => Subscription(
    id: id,
    operatorId: operatorId,
    patternId: patternId,
    tripInstanceId: tripInstanceId,
    stopSequence: stopSequence,
    trigger: trigger ?? this.trigger,
    triggerValue: triggerValue ?? this.triggerValue,
    notifyPassed: notifyPassed ?? this.notifyPassed,
    mutedUntil: clearMute ? null : (mutedUntil ?? this.mutedUntil),
  );
}

/// `post.category`. Riders hide categories in the news list.
enum PostCategory { cancellation, delay, general, event }

PostCategory parsePostCategory(Object? value) => switch (value) {
  'cancellation' => PostCategory.cancellation,
  'delay' => PostCategory.delay,
  'event' => PostCategory.event,
  _ => PostCategory.general,
};

class Post {
  Post(this.json);
  final Json json;
  String get id => json['id'] as String;
  String get operatorId => json['operator_id'] as String;
  String? get routeId => json['route_id'] as String?;
  I18nText get title => I18nText.fromJson(json['title']);
  I18nText get body => I18nText.fromJson(json['body']);
  PostCategory get category => parsePostCategory(json['category']);
  DateTime get publishedAt => DateTime.parse(json['published_at'] as String);
}

enum TripStatus { planned, active, completed, cancelled }

enum StopState { upcoming, approaching, arrived, departed, passed }

class StopEvent {
  StopEvent(this.json);
  final Json json;
  int get sequence => (json['stop_sequence'] as num).toInt();
  StopState get state =>
      StopState.values.byName((json['state'] as String?) ?? 'upcoming');
  DateTime? _t(String key) =>
      json[key] == null ? null : DateTime.parse(json[key] as String);
  DateTime? get eta => _t('eta');
  DateTime? get arrivedAt => _t('arrived_at');
  DateTime? get departedAt => _t('departed_at');
  DateTime? get passedAt => _t('passed_at');
  DateTime? get updatedAt => _t('updated_at');
}

/// A planned stop of a live trip (`trip_instance_stop`).
class PlannedStop {
  PlannedStop(this.json);
  final Json json;
  int get sequence => (json['stop_sequence'] as num).toInt();
  String get stopId => json['stop_id'] as String;
  DateTime? get plannedArrival => _time(json['planned_arrival']);
  DateTime? get plannedDeparture => _time(json['planned_departure']);
  I18nText get stopName => I18nText.fromJson((json['stop'] as Map?)?['name']);

  /// The planned time at the stop: arrival, else departure.
  DateTime? get planned => plannedArrival ?? plannedDeparture;
}

DateTime? _time(Object? value) => value is String ? DateTime.tryParse(value) : null;

class TripInstance {
  TripInstance(this.json);
  final Json json;
  String get id => json['id'] as String;
  String? get operatorId => json['operator_id'] as String?;

  /// A trip started or planned by staff outside the timetable.
  bool get isLive => json['kind'] == 'live';

  /// A live trip with its own planned stops (no pattern), shown on its own.
  bool get isStandaloneLive => isLive && patternId == null;

  /// Live trips are hidden after this.
  DateTime? get visibleUntil => _time(json['visible_until']);
  String? get tripId => json['trip_id'] as String?;
  String? get patternId => json['pattern_id'] as String?;
  String? get routeId => json['route_id'] as String?;
  String get serviceDate => json['service_date'] as String;
  TripStatus get status =>
      TripStatus.values.byName((json['status'] as String?) ?? 'planned');
  DateTime? get offRouteSince => json['off_route_since'] == null
      ? null
      : DateTime.parse(json['off_route_since'] as String);
  I18nText get title => I18nText.fromJson(json['title']);

  List<StopEvent> get events => [
    for (final e in (json['stop_event'] as List? ?? const []))
      StopEvent((e as Map).cast<String, dynamic>()),
  ];

  StopEvent? eventAt(int sequence) {
    for (final e in events) {
      if (e.sequence == sequence) return e;
    }
    return null;
  }

  List<PlannedStop> get plannedStops => [
    for (final s in (json['trip_instance_stop'] as List? ?? const []))
      PlannedStop((s as Map).cast<String, dynamic>()),
  ]..sort((a, b) => a.sequence.compareTo(b.sequence));

  PlannedStop? plannedStopAt(int sequence) {
    for (final s in plannedStops) {
      if (s.sequence == sequence) return s;
    }
    return null;
  }

  /// Whether a live trip is still shown at [now].
  bool visibleAt(DateTime now) => visibleUntil == null || visibleUntil!.isAfter(now);
}

/// Everything the device may see, as one snapshot: what RLS returns for the
/// anonymous user. Cached as JSON for offline use.
class Catalog {
  Catalog(this.json);

  factory Catalog.empty() => Catalog({});

  final Json json;

  List<Json> _list(String key) => [
    for (final e in (json[key] as List? ?? const []))
      (e as Map).cast<String, dynamic>(),
  ];

  late final List<Operator> operators = _list('operators').map(Operator.new).toList();
  late final List<BusRoute> routes =
      _list('routes').map(BusRoute.new).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  late final List<ServiceCalendar> calendars =
      _list('calendars').map(ServiceCalendar.new).toList();
  late final List<Membership> memberships =
      _list('memberships').map(Membership.new).toList();
  late final List<Subscription> subscriptions =
      _list('subscriptions').map(Subscription.fromJson).toList();
  late final List<Post> posts = _list('posts').map(Post.new).toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  /// calendar id → dates it runs ("2026-11-24"), from `rpc/service_days`
  /// (national holidays applied on the server), for
  /// [serviceDaysFrom]..[serviceDaysTo].
  late final Map<String, Set<String>> serviceDays = () {
    final map = <String, Set<String>>{};
    for (final d in _list('service_days')) {
      map.putIfAbsent(d['calendar_id'] as String, () => {}).add(d['service_date'] as String);
    }
    return map;
  }();

  DateTime? get serviceDaysFrom => _date(json['service_days_from']);

  /// Calendars [serviceDays] were loaded for (null: all of them).
  late final Set<String>? serviceDaysCalendars = (json['service_days_calendars'] as List?)
      ?.whereType<String>()
      .toSet();
  DateTime? get serviceDaysTo => _date(json['service_days_to']);

  static DateTime? _date(Object? v) => v is String ? parseDate(v) : null;

  /// Japanese national holidays ("2026-11-23" → name) in the same range.
  late final Map<String, I18nText> holidays = {
    for (final h in _list('holidays')) h['date'] as String: I18nText.fromJson(h['name']),
  };

  /// Whether [calendar] runs on [day]: the server's answer where loaded,
  /// else the calendar's rules with the holidays the app knows.
  bool runsOn(ServiceCalendar calendar, DateTime day) {
    final d = dateOnly(day);
    final from = serviceDaysFrom;
    final to = serviceDaysTo;
    final covered = serviceDaysCalendars?.contains(calendar.id) ?? true;
    if (covered && from != null && to != null && !d.isBefore(from) && !d.isAfter(to)) {
      return serviceDays[calendar.id]?.contains(formatDate(d)) ?? false;
    }
    if (!calendar.runsOn(d)) return false;
    // An added exception wins over a holiday, as on the server.
    final added = calendar.exceptions.any((e) => e.added && e.covers(d));
    return added || !calendar.skipNationalHolidays || !holidays.containsKey(formatDate(d));
  }

  /// route_id → can_see_map for any audience the device is a member of.
  late final Map<String, bool> _routeMap = {
    for (final ar in _list('audience_routes'))
      ar['route_id'] as String: false,
    for (final ar in _list('audience_routes'))
      if (ar['can_see_map'] == true) ar['route_id'] as String: true,
  };

  Operator? operator(String id) {
    for (final o in operators) {
      if (o.id == id) return o;
    }
    return null;
  }

  BusRoute? route(String id) {
    for (final r in routes) {
      if (r.id == id) return r;
    }
    return null;
  }

  ServiceCalendar? calendar(String id) {
    for (final c in calendars) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The route and pattern a pattern id belongs to.
  (BusRoute, TripPattern)? pattern(String patternId) {
    for (final r in routes) {
      for (final p in r.patterns) {
        if (p.id == patternId) return (r, p);
      }
    }
    return null;
  }

  RouteVisibility visibilityOf(BusRoute route) =>
      route.visibility ??
      operator(route.operatorId)?.defaultVisibility ??
      RouteVisibility.invitedEta;

  /// Same rule as private.route_access on the server: public routes, and
  /// invited_map routes for members of an audience with can_see_map.
  bool canSeeMap(BusRoute route) => switch (visibilityOf(route)) {
    RouteVisibility.public => true,
    RouteVisibility.invitedMap => _routeMap[route.id] ?? false,
    RouteVisibility.invitedEta => false,
  };

  /// Operators the device is an active member of.
  Set<String> get memberOperatorIds => {
    for (final m in memberships)
      if (m.active) m.operatorId,
  };

  Subscription? subscriptionFor(String patternId, int sequence) {
    for (final s in subscriptions) {
      if (s.patternId == patternId && s.stopSequence == sequence) return s;
    }
    return null;
  }

  Subscription? liveSubscriptionFor(String tripInstanceId, int sequence) {
    for (final s in subscriptions) {
      if (s.tripInstanceId == tripInstanceId && s.stopSequence == sequence) return s;
    }
    return null;
  }

  List<ServiceCalendar> calendarsOfRoute(BusRoute route) {
    final ids = {
      for (final p in route.patterns)
        for (final t in p.trips) t.calendarId,
    };
    return calendars.where((c) => ids.contains(c.id)).toList();
  }
}

/// Narrows the catalog to what belongs to the device's routes.
///
/// Routes come from `rpc/my_routes` (joined operators plus followed routes)
/// and posts are filtered by RLS (general posts for members only), so this
/// only drops operators and calendars that no route of the device uses:
/// `operator` and `service_calendar` also return every public operator's
/// rows.
Json visibleCatalog(Json raw) {
  List<Json> list(String key) => [
    for (final e in (raw[key] as List? ?? const [])) (e as Map).cast<String, dynamic>(),
  ];
  final members = {
    for (final m in list('memberships'))
      if (m['revoked_at'] == null) m['operator_id'] as String,
  };
  final routes = list('routes');
  final operatorIds = {...members, for (final r in routes) r['operator_id'] as String};
  final calendarIds = {
    for (final r in routes)
      for (final p in (r['trip_pattern'] as List? ?? const []))
        for (final t in ((p as Map)['trip'] as List? ?? const []))
          (t as Map)['service_calendar_id'] as String,
  };
  return {
    ...raw,
    'operators': [
      for (final o in list('operators'))
        if (operatorIds.contains(o['id'])) o,
    ],
    'calendars': [
      for (final c in list('calendars'))
        if (calendarIds.contains(c['id'])) c,
    ],
  };
}
