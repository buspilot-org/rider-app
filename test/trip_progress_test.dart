import 'package:buspilot_rider/src/data/arrivals.dart';
import 'package:buspilot_rider/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

/// 2026-11-23 hh:mm in Kobe.
DateTime kobe(int h, int m) => DateTime.utc(2026, 11, 23, h - 9, m);

void main() {
  setUpAll(initTimeZones);
  final catalog = Catalog(demoCatalog());
  final op = catalog.operator(opId);
  final pattern = catalog.routes.single.patterns.single;
  final trip = pattern.trips.first; // 07:30

  Visit v(VisitKind kind, DateTime? time, {Trip? trip, TripInstance? instance}) =>
      Visit(kind: kind, scheduled: null, time: time, trip: trip, instance: instance);

  test('timetable start without events (07:30 → 07:51)', () {
    final i = TripInstance(instance(id: 'i', tripId: trip0730, serviceDate: '2026-11-23', status: 'active'));
    final visit = v(VisitKind.onTheWay, kobe(7, 51), trip: trip, instance: i);
    expect(tripStart(visit, op, kobe(7, 40))!.isAtSameMomentAs(kobe(7, 30)), isTrue);
    expect(tripProgress(visit, op, kobe(7, 40)), closeTo(10 / 21, 0.001));
  });

  test('the service date of the instance, not of now (after midnight)', () {
    final i = TripInstance(instance(id: 'i', tripId: trip0730, serviceDate: '2026-11-22', status: 'active'));
    final visit = v(VisitKind.onTheWay, kobe(7, 51), trip: trip, instance: i);
    expect(tripStart(visit, op, kobe(7, 40))!.isAtSameMomentAs(DateTime.utc(2026, 11, 21, 22, 30)), isTrue);
  });

  test('live trip: the first planned stop', () {
    final i = TripInstance(liveTrip(status: 'active'));
    final visit = v(VisitKind.onTheWay, DateTime.utc(2026, 11, 23, 1, 20), instance: i);
    expect(tripStart(visit, op, kobe(10, 0))!.isAtSameMomentAs(DateTime.utc(2026, 11, 23, 1, 0)), isTrue);
    expect(tripProgress(visit, op, kobe(10, 10)), closeTo(0.5, 0.001));
  });

  test('before the start: 0; at the stop: 1; not on the way: null', () {
    final visit = v(VisitKind.delayed, kobe(7, 51), trip: trip);
    expect(tripProgress(visit, op, kobe(7, 0)), 0);
    expect(tripProgress(v(VisitKind.atStop, kobe(7, 51)), op, kobe(7, 51)), 1);
    for (final k in [VisitKind.scheduled, VisitKind.passed, VisitKind.cancelled]) {
      expect(tripProgress(v(k, kobe(7, 51), trip: trip), op, kobe(7, 40)), isNull);
    }
  });

  test('arrival at (or within a second of) the start: null, never NaN', () {
    final i = TripInstance(liveTrip(status: 'active'));
    final start = DateTime.utc(2026, 11, 23, 1, 0);
    expect(tripProgress(v(VisitKind.onTheWay, start, instance: i), op, start), isNull);
    expect(
      tripProgress(v(VisitKind.onTheWay, start.add(const Duration(milliseconds: 500)), instance: i), op, start),
      isNull,
    );
  });
}
