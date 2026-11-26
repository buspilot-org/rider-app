import 'package:buspilot_rider/src/data/models.dart';
import 'package:buspilot_rider/src/ui/stop_card.dart';
import 'package:buspilot_rider/src/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

/// Follows Kitano-zaka (second visit, sequence 5: 07:51 on the 07:30 trip).
Json _sub() => {
  'id': 'sub-5',
  'operator_id': opId,
  'pattern_id': patternId,
  'stop_sequence': 5,
  'trigger': 'minutes',
  'trigger_value': 5,
  'notify_passed': false,
  'muted_until': null,
};

/// 2026-11-23 hh:mm in Kobe.
DateTime kobe(int h, int m) => DateTime.utc(2026, 11, 23, h - 9, m);

/// The 07:30 trip, on its way: left Shin-Kobe at 07:31, then [events].
Json _active(List<Json> events, {DateTime? offRouteSince}) => {
  ...instance(
    id: 'ti-0730',
    tripId: trip0730,
    serviceDate: '2026-11-23',
    status: 'active',
    events: [
      event(1, 'departed', arrived: kobe(7, 30), departed: kobe(7, 31)),
      ...events,
    ],
  ),
  'off_route_since': offRouteSince?.toUtc().toIso8601String(),
};

Future<void> _pump(WidgetTester tester, List<Json> instances, {DateTime? now}) async {
  final api = FakeApi(joined: true, instances: instances);
  api.subscriptions.add(_sub());
  await pumpApp(tester, api: api, now: now ?? kobe(7, 40));
}

const light = BuspilotColors.light;

/// The status chip: its text, tint and text colour.
void _expectChip(WidgetTester tester, String text, Color tint, Color color) {
  final chip = find.byKey(const ValueKey('stop-status'));
  expect(chip, findsOneWidget);
  final box = tester.widget<Container>(chip).decoration! as BoxDecoration;
  expect(box.color, tint);
  final label = tester.widget<Text>(find.descendant(of: chip, matching: find.byType(Text)));
  expect(label.data, text);
  expect(label.style?.color, color);
}

/// The colour of the large ETA number [n] in the line [text].
Color? _etaColor(WidgetTester tester, String text, String n) {
  final rich = tester.widget<RichText>(find.text(text, findRichText: true));
  Color? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == n) found = span.style?.color;
    return found == null;
  });
  return found;
}

void main() {
  setUpAll(initTimeZones);

  testWidgets('on time: green chip, ETA in primary, bus on the progress bar', (tester) async {
    // ETA 07:52 for 07:51: one minute is not late.
    await _pump(tester, [
      _active([event(5, 'upcoming', eta: kobe(7, 52))]),
    ]);
    _expectChip(tester, 'On time', light.onTimeTint, light.onTimeText);
    expect(find.text('in 12 min', findRichText: true), findsOneWidget);
    expect(_etaColor(tester, 'in 12 min', '12'), light.primary);
    expect(find.text('Arrives at Kitano-zaka at 07:52'), findsOneWidget);
    expect(find.byKey(const ValueKey('bus-dot')), findsOneWidget);
    // 9 of 21 minutes since the bus left Shin-Kobe.
    final bar = tester.widget<TripProgressBar>(find.byType(TripProgressBar));
    expect(bar.value, closeTo(9 / 21, 0.001));
    final dot = tester.widget<Container>(find.byKey(const ValueKey('bus-dot')));
    expect((dot.decoration! as BoxDecoration).color, light.accent);
  });

  testWidgets('delayed: calm words and the new time', (tester) async {
    await _pump(tester, [
      _active([event(5, 'upcoming', eta: kobe(7, 57))]),
    ]);
    _expectChip(tester, 'A little late', light.delayedTint, light.delayedText);
    expect(find.text('in 17 min', findRichText: true), findsOneWidget);
    expect(_etaColor(tester, 'in 17 min', '17'), light.delayedText);
    expect(find.text('Should reach Kitano-zaka around 07:57 (about 6 min late)'), findsOneWidget);
  });

  testWidgets('arriving: within 3 minutes, in the arriving text colour', (tester) async {
    await _pump(tester, [
      _active([event(5, 'upcoming', eta: kobe(7, 42))]),
    ]);
    _expectChip(tester, 'Arriving soon', light.arrivingTint, light.arrivingText);
    expect(find.text('in 2 min', findRichText: true), findsOneWidget);
    // Yamabuki is a fill only: the number uses the arriving text colour.
    expect(_etaColor(tester, 'in 2 min', '2'), light.arrivingText);
  });

  testWidgets('at the stop', (tester) async {
    await _pump(tester, [
      _active([event(5, 'arrived', arrived: kobe(7, 39))]),
    ]);
    _expectChip(tester, 'At the stop', light.arrivingTint, light.arrivingText);
    expect(find.text('At your stop'), findsOneWidget);
  });

  testWidgets('position unknown: grey chip and a next step', (tester) async {
    await _pump(tester, [
      _active([event(5, 'upcoming', eta: kobe(7, 52))], offRouteSince: kobe(7, 36)),
    ]);
    _expectChip(tester, 'Position unknown', light.unknownTint, light.unknownText);
    expect(find.text('We are checking where the bus is (since 07:36). Please wait a moment.'), findsOneWidget);
  });

  testWidgets('cancelled', (tester) async {
    await _pump(tester, [instance(id: 'ti-0730', tripId: trip0730, serviceDate: '2026-11-23', status: 'cancelled')]);
    final scheme = Theme.of(tester.element(find.byKey(const ValueKey('stop-status')))).colorScheme;
    _expectChip(tester, 'Cancelled', scheme.errorContainer, scheme.onErrorContainer);
    expect(find.text('Cancelled (07:51)'), findsOneWidget);
    expect(find.byKey(const ValueKey('bus-dot')), findsNothing);
  });

  testWidgets('not started: the timetable time, no progress bar', (tester) async {
    await _pump(tester, const []);
    _expectChip(tester, 'Not started', light.primaryTint, light.onPrimaryTint);
    expect(find.text('in 11 min', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('bus-dot')), findsNothing);
  });

  testWidgets('more than an hour ahead: the time instead of minutes', (tester) async {
    await _pump(tester, const [], now: kobe(6, 30));
    expect(find.text('07:51'), findsOneWidget);
    expect(find.text('Arrives at Kitano-zaka at 07:51'), findsOneWidget);
  });

  testWidgets('all buses passed: no chip', (tester) async {
    await _pump(tester, const [], now: kobe(10, 0));
    expect(find.byKey(const ValueKey('stop-status')), findsNothing);
    expect(find.text('Passed 08:31'), findsOneWidget);
  });

  testWidgets('Japanese and German wording', (tester) async {
    final api = FakeApi(
      joined: true,
      instances: [
        _active([event(5, 'upcoming', eta: kobe(7, 57))]),
      ],
    );
    api.subscriptions.add(_sub());
    await pumpApp(tester, api: api, now: kobe(7, 40), language: 'ja');
    expect(find.text('少し遅れています'), findsOneWidget);
    expect(find.text('あと 17分', findRichText: true), findsOneWidget);
    expect(find.text('「北野坂」に 07:57 ごろ到着予定（約6分遅れ）'), findsOneWidget);

    await pumpApp(tester, api: api, now: kobe(7, 40), language: 'de');
    expect(find.text('Etwas später'), findsOneWidget);
    expect(find.text('in 17 Min.', findRichText: true), findsOneWidget);
  });
}
