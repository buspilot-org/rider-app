import 'package:buspilot_rider/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

Json _sub(int seq) => {
  'id': 'sub-$seq',
  'operator_id': opId,
  'pattern_id': patternId,
  'stop_sequence': seq,
  'trigger': 'minutes',
  'trigger_value': 5,
  'notify_passed': false,
  'muted_until': null,
};

/// 2026-11-23 hh:mm in Kobe.
DateTime kobe(int h, int m) => DateTime.utc(2026, 11, 23, h - 9, m);

void main() {
  setUpAll(initTimeZones);

  testWidgets('shows the next arrival per followed stop, late and scheduled', (tester) async {
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
            event(2, 'departed', arrived: kobe(7, 38), departed: kobe(7, 39)),
            // Scheduled 07:51; ETA 07:55 → about 4 minutes late.
            event(5, 'upcoming', eta: kobe(7, 55)),
          ],
        ),
      ],
    );
    api.subscriptions
      ..add(_sub(1))
      ..add(_sub(5));

    await pumpApp(tester, api: api);

    expect(find.text('My stops today'), findsOneWidget);
    // Second visit of Kitano-zaka: the 07:30 trip is on its way, late.
    expect(find.text('Delayed ~4 min · 07:55'), findsOneWidget);
    // Shin-Kobe: the 07:30 bus has left, next is the 08:10 trip.
    expect(find.text('08:10 · in 30 min'), findsOneWidget);
    expect(find.text('Kitano-zaka'), findsOneWidget);
    expect(find.text('Shin-Kobe Station'), findsOneWidget);
    expect(find.text('As of ${_hm(mondayMorning)}'), findsOneWidget);
  });

  testWidgets('cancelled trip and no bus on Saturday', (tester) async {
    final api = FakeApi(
      joined: true,
      instances: [
        instance(id: 'ti-0730', tripId: trip0730, serviceDate: '2026-11-23', status: 'cancelled'),
      ],
    );
    api.subscriptions.add(_sub(3));
    await pumpApp(tester, api: api, now: kobe(7, 0));
    expect(find.text('Cancelled (07:39)'), findsOneWidget);
  });

  testWidgets('after a cancelled trip\'s time, the next trip counts', (tester) async {
    final api = FakeApi(
      joined: true,
      instances: [
        instance(id: 'ti-0730', tripId: trip0730, serviceDate: '2026-11-23', status: 'cancelled'),
      ],
    );
    api.subscriptions.add(_sub(3));
    // 07:50: still within 15 minutes of 07:39, the cancellation shows.
    await pumpApp(tester, api: api, now: kobe(7, 50));
    expect(find.text('Cancelled (07:39)'), findsOneWidget);
    // 08:00: the 07:30 trip (07:39 at Sannomiya) is over; 08:10 is next.
    await pumpApp(tester, api: api, now: kobe(8, 0));
    expect(find.text('08:19 · in 19 min'), findsOneWidget);
  });

  testWidgets('no bus today on a weekend', (tester) async {
    final api = FakeApi(joined: true);
    api.subscriptions.add(_sub(3));
    // Saturday 2026-11-28 08:00 in Kobe.
    await pumpApp(tester, api: api, now: DateTime.utc(2026, 11, 27, 23));
    expect(find.text('No bus today'), findsOneWidget);
  });

  testWidgets('keeps the last state when offline', (tester) async {
    final api = FakeApi(joined: true);
    api.subscriptions.add(_sub(1));
    final state = await pumpApp(tester, api: api);

    api.offline = true;
    await tester.runAsync(state.refresh);
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline · as of'), findsOneWidget);
    expect(find.text('Shin-Kobe Station'), findsOneWidget);
  });

  testWidgets('starts from the cache without network', (tester) async {
    final api = FakeApi(joined: true);
    api.subscriptions.add(_sub(1));
    final store = await freshStore();
    await pumpApp(tester, api: api, store: store);

    // Next start: no network, same phone storage.
    final offlineApi = FakeApi(joined: true)..offline = true;
    await pumpApp(tester, api: offlineApi, store: store);
    expect(find.textContaining('Offline · as of'), findsOneWidget);
    expect(find.text('Shin-Kobe Station'), findsOneWidget);
  });

  testWidgets('Japanese', (tester) async {
    final api = FakeApi(joined: true);
    api.subscriptions.add(_sub(5));
    await pumpApp(tester, api: api, language: 'ja');
    expect(find.text('今日のマイ停留所'), findsOneWidget);
    expect(find.text('北野坂'), findsOneWidget);
  });
}

String _hm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
