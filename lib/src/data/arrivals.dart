import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// What a rider sees for one visit of a bus at a stop.
enum VisitKind {
  /// Not started yet; [Visit.time] is the scheduled time (or the ETA).
  scheduled,

  /// The bus is on its way; [Visit.time] is the ETA.
  onTheWay,

  /// On its way and late by [Visit.delay].
  delayed,

  /// The bus is at the stop now.
  atStop,

  /// The bus has left or passed the stop; [Visit.time] is when.
  passed,

  /// This trip is cancelled.
  cancelled,
}

/// Status of a whole trip, for the route status line.
enum TripPhase { notStarted, onTheWay, finished, cancelled }

/// One run of the bus past a stop (a trip of the pattern on the service day).
class Visit {
  Visit({
    required this.kind,
    required this.scheduled,
    required this.time,
    this.trip,
    this.instance,
    this.event,
  });

  final VisitKind kind;

  /// Scheduled arrival (null for live trips without a timetable).
  final DateTime? scheduled;

  /// The time to show: ETA, scheduled time, or when it arrived / passed.
  final DateTime? time;
  final Trip? trip;
  final TripInstance? instance;
  final StopEvent? event;

  Duration get delay => (time != null && scheduled != null)
      ? time!.difference(scheduled!)
      : Duration.zero;

  TripPhase get tripPhase => switch (instance?.status) {
    TripStatus.cancelled => TripPhase.cancelled,
    TripStatus.completed => TripPhase.finished,
    TripStatus.active => TripPhase.onTheWay,
    _ => TripPhase.notStarted,
  };
}

/// The answer for a followed stop: the next visit today, or why there is none.
class NextArrival {
  NextArrival({required this.next, required this.visits});

  /// The visit to show: the next one that has not passed, else the last one.
  /// Null when there is no bus today.
  final Visit? next;
  final List<Visit> visits;

  bool get noBusToday => visits.isEmpty;
}

/// Late by at least this much counts as "delayed".
const delayThreshold = Duration(minutes: 3);

/// A visit without live data counts as passed this long after its time.
const _assumePassedAfter = Duration(minutes: 15);

tz.Location locationOf(Operator? op) {
  try {
    return tz.getLocation(op?.timezone ?? 'Asia/Tokyo');
  } catch (_) {
    return tz.getLocation('Asia/Tokyo');
  }
}

/// The service date ("today") in the operator's time zone.
DateTime serviceDay(tz.Location loc, DateTime now) {
  final local = tz.TZDateTime.from(now, loc);
  return DateTime.utc(local.year, local.month, local.day);
}

/// Service day + seconds since local midnight, as an instant.
DateTime atOffset(tz.Location loc, DateTime day, int seconds) =>
    tz.TZDateTime(loc, day.year, day.month, day.day).add(Duration(seconds: seconds));

/// All visits of [pattern] at [sequence] on the service day of [now], from the
/// timetable (trips whose calendar runs today) and the live trip instances.
List<Visit> visitsAt({
  required Catalog catalog,
  required BusRoute route,
  required TripPattern pattern,
  required int sequence,
  required List<TripInstance> instances,
  required DateTime now,
}) {
  final loc = locationOf(catalog.operator(route.operatorId));
  final day = serviceDay(loc, now);
  final dayKey = formatDate(day);
  final stop = pattern.stopAt(sequence);
  if (stop == null) return const [];

  final todays = instances
      .where((i) => i.serviceDate == dayKey && i.patternId == pattern.id)
      .toList();
  final visits = <Visit>[];
  final used = <String>{};

  for (final trip in pattern.trips) {
    TripInstance? instance;
    for (final i in todays) {
      if (i.tripId == trip.id) instance = i;
    }
    final calendar = catalog.calendar(trip.calendarId);
    final runs = calendar != null && catalog.runsOn(calendar, day);
    if (!runs && instance == null) continue;
    if (instance != null) used.add(instance.id);
    final scheduled = atOffset(loc, day, trip.startTime + stop.arrivalOffset);
    visits.add(_visit(scheduled, trip, instance, sequence, now));
  }
  // Live trips started by a driver, without a timetable entry.
  for (final i in todays) {
    if (used.contains(i.id) || i.tripId != null) continue;
    visits.add(_visit(null, null, i, sequence, now));
  }
  visits.sort((a, b) {
    final ta = a.scheduled ?? a.time;
    final tb = b.scheduled ?? b.time;
    if (ta == null || tb == null) return 0;
    return ta.compareTo(tb);
  });
  return visits;
}

Visit _visit(
  DateTime? scheduled,
  Trip? trip,
  TripInstance? instance,
  int sequence,
  DateTime now,
) {
  final event = instance?.eventAt(sequence);
  Visit v(VisitKind kind, DateTime? time) => Visit(
    kind: kind,
    scheduled: scheduled,
    time: time,
    trip: trip,
    instance: instance,
    event: event,
  );

  if (instance?.status == TripStatus.cancelled) {
    return v(VisitKind.cancelled, scheduled);
  }
  final state = event?.state;
  if (state == StopState.departed || state == StopState.passed) {
    return v(
      VisitKind.passed,
      event!.departedAt ?? event.passedAt ?? event.arrivedAt ?? scheduled,
    );
  }
  if (state == StopState.arrived) {
    return v(VisitKind.atStop, event!.arrivedAt);
  }
  if (instance?.status == TripStatus.completed) {
    return v(VisitKind.passed, event?.eta ?? scheduled);
  }
  final eta = event?.eta ?? scheduled;
  if (instance?.status == TripStatus.active) {
    final late = scheduled != null &&
        eta != null &&
        eta.difference(scheduled) >= delayThreshold;
    return v(late ? VisitKind.delayed : VisitKind.onTheWay, eta);
  }
  // Planned or no live data yet: after its time, assume it has gone.
  if (eta != null && now.isAfter(eta.add(_assumePassedAfter))) {
    return v(VisitKind.passed, eta);
  }
  return v(VisitKind.scheduled, eta);
}

/// The visit to show on the home card.
NextArrival nextArrival({
  required Catalog catalog,
  required BusRoute route,
  required TripPattern pattern,
  required int sequence,
  required List<TripInstance> instances,
  required DateTime now,
}) {
  final visits = visitsAt(
    catalog: catalog,
    route: route,
    pattern: pattern,
    sequence: sequence,
    instances: instances,
    now: now,
  );
  Visit? next;
  for (final v in visits) {
    final at = v.scheduled ?? v.time;
    // A cancelled trip is news until its time is over, then the next one
    // counts.
    final cancelledAndOver = v.kind == VisitKind.cancelled &&
        at != null &&
        now.isAfter(at.add(_assumePassedAfter));
    if (v.kind != VisitKind.passed && !cancelledAndOver) {
      next = v;
      break;
    }
  }
  next ??= visits.isEmpty ? null : visits.last;
  return NextArrival(next: next, visits: visits);
}

/// The visit of a live trip with planned stops at its stop [sequence]: the
/// planned time is the "scheduled" time, the stop event gives state and ETA.
Visit? liveVisitAt(TripInstance trip, int sequence, DateTime now) {
  final stop = trip.plannedStopAt(sequence);
  if (stop == null) return null;
  return _visit(stop.planned, null, trip, sequence, now);
}

/// The next stop of a live trip that the bus has not reached yet, with its
/// visit; null when all stops are done or the trip is cancelled.
({PlannedStop stop, Visit visit})? nextLiveStop(TripInstance trip, DateTime now) {
  for (final s in trip.plannedStops) {
    final v = liveVisitAt(trip, s.sequence, now);
    if (v == null) continue;
    if (v.kind == VisitKind.cancelled) return null;
    if (v.kind != VisitKind.passed) return (stop: s, visit: v);
  }
  return null;
}

/// The trip instance to show on the route screen by default: an active one,
/// else the next one to start, else the last of the day.
Visit? currentVisitOfPattern({
  required Catalog catalog,
  required BusRoute route,
  required TripPattern pattern,
  required List<TripInstance> instances,
  required DateTime now,
}) {
  final last = pattern.stops.isEmpty ? null : pattern.stops.last.sequence;
  if (last == null) return null;
  // Visits at the last stop: a trip is over once the bus has passed it.
  return nextArrival(
    catalog: catalog,
    route: route,
    pattern: pattern,
    sequence: last,
    instances: instances,
    now: now,
  ).next;
}
