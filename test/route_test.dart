import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:buspilot_rider/src/data/models.dart';
import 'package:buspilot_rider/src/state/app_state.dart';
import 'package:buspilot_rider/src/ui/home_screen.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

DateTime kobe(int h, int m) => DateTime.utc(2026, 11, 23, h - 9, m);

void main() {
  setUpAll(initTimeZones);

  Future<void> openRoute(WidgetTester tester) async {
    await tester.tap(find.text('Morning route A'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists stops in order; a stop served twice appears twice', (tester) async {
    final api = FakeApi(
      joined: true,
      instances: [
        instance(
          id: 'ti-0730',
          tripId: trip0730,
          serviceDate: '2026-11-23',
          status: 'active',
          events: [
            event(1, 'departed', arrived: kobe(7, 30), departed: kobe(7, 31)),
            event(2, 'departed', arrived: kobe(7, 35), departed: kobe(7, 36)),
            event(3, 'arrived', arrived: kobe(7, 39)),
            event(4, 'upcoming', eta: kobe(7, 45)),
            event(5, 'upcoming', eta: kobe(7, 51)),
            event(6, 'upcoming', eta: kobe(7, 55)),
          ],
        ),
      ],
    );
    await pumpApp(tester, api: api);
    await openRoute(tester);

    expect(find.text('Kitano-zaka'), findsNWidgets(2));
    expect(find.text('Shin-Kobe Station'), findsOneWidget);
    expect(find.text('School'), findsOneWidget);
    // Today's trips to choose from.
    expect(find.widgetWithText(ChoiceChip, '07:30'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '08:10'), findsOneWidget);
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Passed'), findsNWidgets(2));
    expect(find.text('Bus at stop'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Order follows stop_sequence.
    final y = [
      for (final seq in [1, 2, 3, 4, 5, 6])
        tester.getTopLeft(find.byKey(ValueKey('stop-$seq'))).dy,
    ];
    expect(y, orderedEquals([...y]..sort()));

    // No map for an arrival-times-only audience.
    expect(find.text('Map not available'), findsNothing);
  });

  testWidgets('follow the second visit of a stop with alert settings', (tester) async {
    final api = FakeApi(joined: true);
    await pumpApp(tester, api: api);
    await openRoute(tester);

    await tester.tap(find.byKey(const ValueKey('stop-5')));
    await tester.pumpAndSettle();
    expect(find.text('Tell me when the bus is …'), findsOneWidget);

    await tester.tap(find.text('10 min away'));
    await tester.tap(find.text('Also tell me when the bus has passed my stop'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('save-alert')), 200);
    await tester.tap(find.byKey(const Key('save-alert')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(api.calls, contains('saveSubscription:5'));
    final saved = api.subscriptions.single;
    expect(saved['stop_sequence'], 5);
    expect(saved['trigger'], 'minutes');
    expect(saved['trigger_value'], 10);
    expect(saved['notify_passed'], true);

    // Back on the route; then home shows the followed stop.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kitano-zaka'), findsOneWidget);
    expect(find.text('Follow your stop'), findsNothing);
  });

  testWidgets('a route without patterns shows no bus instead of crashing', (tester) async {
    await pumpApp(tester, api: FakeApi(joined: true));
    // A route an editor just created, before it has patterns.
    final state = AppScope.read(tester.element(find.byType(HomeScreen)));
    final json = demoCatalog();
    (json['routes'] as List).single['trip_pattern'] = <Map<String, dynamic>>[];
    state.catalog = Catalog(json);
    await tester.tap(find.text('Morning route A'));
    await tester.pumpAndSettle();
    expect(find.text('No bus today'), findsOneWidget);
  });

  testWidgets('pause alerts for today', (tester) async {
    final api = FakeApi(joined: true);
    api.subscriptions.add({
      'id': 'sub-2',
      'operator_id': opId,
      'pattern_id': patternId,
      'stop_sequence': 2,
      'trigger': 'stops',
      'trigger_value': 1,
      'notify_passed': false,
      'muted_until': null,
    });
    await pumpApp(tester, api: api);
    await tester.tap(find.byTooltip('Alert settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('save-alert')), 200);
    await tester.tap(find.byKey(const Key('save-alert')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final saved = api.subscriptions.single;
    // Paused until the next midnight in Kobe.
    expect(saved['muted_until'], '2026-11-23T15:00:00.000Z');
    expect(saved['trigger'], 'stops');
    expect(find.textContaining('Paused through'), findsOneWidget);
  });
}
