// The labels of the bus on the route map (brand App and Icons boards):
// "あと5分" to the first followed stop ahead, "+5分" when the bus is late.
import 'package:buspilot_rider/src/data/arrivals.dart';
import 'package:buspilot_rider/src/ui/route_screen.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 30, 23, 40);
DateTime at(int minutes) => now.add(Duration(minutes: minutes));

Visit visit(VisitKind kind, {required int scheduled, int? eta}) =>
    Visit(kind: kind, scheduled: at(scheduled), time: at(eta ?? scheduled));

void main() {
  test('ETA to the first followed stop the bus has not reached', () {
    final labels = mapBusLabels(
      followed: [
        visit(VisitKind.passed, scheduled: -5),
        visit(VisitKind.atStop, scheduled: 0),
        visit(VisitKind.onTheWay, scheduled: 5),
        visit(VisitKind.onTheWay, scheduled: 12),
      ],
      next: visit(VisitKind.onTheWay, scheduled: 2),
      now: now,
    );
    expect(labels.eta, 5);
    expect(labels.delay, isNull);
  });

  test('delay from the followed stop, not from the next stop', () {
    final labels = mapBusLabels(
      followed: [visit(VisitKind.delayed, scheduled: 5, eta: 11)],
      next: visit(VisitKind.onTheWay, scheduled: 2),
      now: now,
    );
    expect(labels.eta, 11);
    expect(labels.delay, 6);
  });

  test('without a followed stop ahead: no ETA, delay from the next stop', () {
    final labels = mapBusLabels(
      followed: [visit(VisitKind.passed, scheduled: -5), null],
      next: visit(VisitKind.delayed, scheduled: 2, eta: 6),
      now: now,
    );
    expect(labels.eta, isNull);
    expect(labels.delay, 4);
  });

  test('no ETA label at 0 minutes or beyond the limit', () {
    for (final minutes in [0, mapEtaMaxMinutes + 1]) {
      final labels = mapBusLabels(
        followed: [visit(VisitKind.onTheWay, scheduled: minutes)],
        next: null,
        now: now,
      );
      expect(labels.eta, isNull, reason: '$minutes min');
    }
    final edge = mapBusLabels(
      followed: [visit(VisitKind.onTheWay, scheduled: mapEtaMaxMinutes)],
      next: null,
      now: now,
    );
    expect(edge.eta, mapEtaMaxMinutes);
  });

  test('a cancelled or scheduled stop is not "ahead"', () {
    final labels = mapBusLabels(
      followed: [visit(VisitKind.cancelled, scheduled: 5), visit(VisitKind.scheduled, scheduled: 8)],
      next: visit(VisitKind.scheduled, scheduled: 3),
      now: now,
    );
    expect(labels.eta, isNull);
    expect(labels.delay, isNull);
  });
}
