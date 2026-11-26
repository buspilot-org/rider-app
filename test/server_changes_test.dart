// The app on the server changes of buspilot-org/server#3 and #4: service
// days and holidays, post categories, the mini map limit, live trips with
// planned stops, push messages, join links and branding images.
import 'dart:async';

import 'package:buspilot_rider/src/data/branding.dart';
import 'package:buspilot_rider/src/data/ewkb.dart';
import 'package:buspilot_rider/src/data/invite_link.dart';
import 'package:buspilot_rider/src/data/models.dart';
import 'package:buspilot_rider/src/push/push_alert.dart';
import 'package:buspilot_rider/src/state/app_state.dart';
import 'package:buspilot_rider/src/ui/live_trip_screen.dart';
import 'package:buspilot_rider/src/ui/route_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';
import 'fakes/fake_push.dart';
import 'fakes/harness.dart';

DateTime kobe(int h, int m) => DateTime.utc(2026, 11, 23, h - 9, m);

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

const _labourDay = {'en': 'Labour Thanksgiving Day', 'ja': '勤労感謝の日'};

Json _sub(int seq) => {
  'id': 'sub-$seq',
  'operator_id': opId,
  'pattern_id': patternId,
  'trip_instance_id': null,
  'stop_sequence': seq,
  'trigger': 'minutes',
  'trigger_value': 5,
  'notify_passed': false,
  'muted_until': null,
};

Map<String, String> _alertData({
  String v = '1',
  String kind = 'approaching',
  String patternId = patternId,
  String tripInstanceId = 'ti-0730',
  String seq = '5',
}) => {
  'v': v,
  'type': 'stop_alert',
  'kind': kind,
  'alert_id': 'a1',
  'subscription_id': 'sub-5',
  'operator_id': opId,
  'route_id': routeId,
  'pattern_id': patternId,
  'stop_id': 's2',
  'stop_sequence': seq,
  'trip_instance_id': tripInstanceId,
  'service_date': '2026-11-23',
  'trip_start': '2026-11-22T22:30:00.000Z',
  'eta': '2026-11-22T22:51:00.000Z',
  'delay_s': '',
};

void main() {
  setUpAll(initTimeZones);

  group('join links', () {
    test('canonical fragment link, the path link and the admin console format', () {
      expect(inviteCodeFrom('https://buspilot.org/join#code=DEMO-KOBE-2026'), 'DEMO-KOBE-2026');
      expect(inviteCodeFrom('https://buspilot.org/join/#code=demo-kobe-2026'), 'DEMO-KOBE-2026');
      expect(inviteCodeFrom('https://buspilot.org/join/DEMO-KOBE-2026'), 'DEMO-KOBE-2026');
      expect(inviteCodeFrom('https://app.buspilot.org/join#code=ABCDE-FGHJK'), 'ABCDE-FGHJK');
      expect(inviteCodeFrom('https://app.buspilot.org/join#code=ABCDE%20FGHJK'), 'ABCDE FGHJK');
    });

    test('rejects other hosts, schemes, paths and fragments', () {
      expect(inviteCodeFrom('https://evil.example/join#code=DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('https://app.buspilot.org.evil.example/join#code=DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('http://app.buspilot.org/join#code=DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('https://app.buspilot.org/other#code=DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('https://app.buspilot.org/join#token=DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('https://app.buspilot.org/join#code=%ZZ'), isNull);
      expect(inviteCodeFrom('https://app.buspilot.org/join#code=<script>'), isNull);
      // The admin console host takes the fragment form only.
      expect(inviteCodeFrom('https://app.buspilot.org/join/DEMO-KOBE-2026'), isNull);
    });
  });

  group('branding images', () {
    const backend = 'https://abc.supabase.co';
    String? check(String? url, {String op = opId}) =>
        brandingImageUrl(url, backendUrl: backend, operatorId: op);
    const logo = '$backend/storage/v1/object/public/operator-branding/$opId/logo.png';

    test('only the operator\'s folder in the branding bucket on the backend', () {
      expect(check(logo), logo);
      expect(check(null), isNull);
      expect(check('https://cdn.example/logo.png'), isNull);
      expect(check('http://abc.supabase.co/storage/v1/object/public/operator-branding/$opId/logo.png'), isNull);
      expect(check('https://abc.supabase.co:8443/storage/v1/object/public/operator-branding/$opId/logo.png'), isNull);
      expect(check('https://abc.supabase.co/storage/v1/object/public/other-bucket/$opId/logo.png'), isNull);
      // Another operator's folder, traversal, query strings.
      expect(check(logo, op: 'someone-else'), isNull);
      expect(check('$backend/storage/v1/object/public/operator-branding/$opId/../x/logo.png'), isNull);
      expect(check('$backend/storage/v1/object/public/operator-branding/$opId/a%2F..%2Fb.png'), isNull);
      expect(check('$logo?download=1'), isNull);
      expect(check('$backend/storage/v1/object/public/operator-branding/$opId/logo%20x.png'), isNull);
      expect(check('$backend/storage/v1/object/public/operator-branding/$opId/logo%3Cx%3E.png'), isNull);
      expect(check('$backend/storage/v1/object/public/operator-branding/$opId/2026/cover_v2.webp'), isNotNull);
      expect(check('https://user@abc.supabase.co/storage/v1/object/public/operator-branding/$opId/logo.png'), isNull);
      expect(brandingImageUrl(logo, backendUrl: '', operatorId: opId), isNull);
    });

    test('logo_url and cover_url; the old key "logo" is gone', () {
      final op = Operator({
        'id': opId,
        'branding': {'logo': 'https://x/logo.png', 'cover_url': 'https://x/cover.png'},
      });
      expect(op.logoUrl, isNull);
      expect(op.coverUrl, 'https://x/cover.png');
    });
  });

  group('push messages', () {
    test('version 1 stop alerts parse; other versions, types and kinds are ignored', () {
      final a = PushAlert.fromData(_alertData(), title: 'A', body: 'B')!;
      expect(a.kind, AlertKind.approaching);
      expect(a.patternId, patternId);
      expect(a.stopSequence, 5);
      expect(a.tripInstanceId, 'ti-0730');
      expect(a.title, 'A');
      expect(PushAlert.fromData(_alertData(v: '2')), isNull);
      expect(PushAlert.fromData({..._alertData(), 'v': null}), isNull);
      expect(PushAlert.fromData(_alertData(kind: 'boarding')), isNull);
      expect(PushAlert.fromData({..._alertData(), 'type': 'post'}), isNull);
      for (final k in ['arrived', 'passed', 'delayed', 'cancelled']) {
        expect(PushAlert.fromData(_alertData(kind: k)), isNotNull);
      }
      // Empty strings are "not set" (live trips have no pattern).
      final live = PushAlert.fromData(_alertData(patternId: '', tripInstanceId: 'live-1'))!;
      expect(live.patternId, isNull);
      expect(live.tripInstanceId, 'live-1');
      // A stop sequence that is not a number: no stop to highlight.
      expect(PushAlert.fromData(_alertData(seq: 'x'))!.stopSequence, isNull);
    });

    testWidgets('a tapped notification opens the route at that stop and trip', (tester) async {
      phoneSize(tester);
      final push = FakePush();
      final api = FakeApi(joined: true, instances: [
        instance(id: 'ti-0730', tripId: trip0730, serviceDate: '2026-11-23', status: 'active'),
        instance(id: 'ti-0810', tripId: trip0810, serviceDate: '2026-11-23', status: 'planned'),
      ]);
      await pumpApp(tester, api: api, push: push);
      push.opened.add(PushAlert.fromData(_alertData(tripInstanceId: 'ti-0810'))!);
      await tester.pumpAndSettle();
      final screen = tester.widget<RouteScreen>(find.byType(RouteScreen));
      expect(screen.highlightSequence, 5);
      expect(screen.tripInstanceId, 'ti-0810');
      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '08:10'));
      expect(chip.selected, isTrue);
    });

    testWidgets('pattern and trip in one alert: the route, that trip; bad sequence highlights nothing', (tester) async {
      final push = FakePush();
      final api = FakeApi(joined: true, instances: [
        instance(id: 'ti-0730', tripId: trip0730, serviceDate: '2026-11-23', status: 'active'),
      ]);
      await pumpApp(tester, api: api, push: push);
      push.opened.add(PushAlert.fromData(_alertData(seq: 'x'))!);
      await tester.pumpAndSettle();
      final screen = tester.widget<RouteScreen>(find.byType(RouteScreen));
      expect(screen.patternId, patternId);
      expect(screen.tripInstanceId, 'ti-0730');
      expect(screen.highlightSequence, isNull);
      expect(find.byType(LiveTripScreen), findsNothing);
    });

    testWidgets('a pending notification is dropped after delete my data', (tester) async {
      final push = FakePush();
      final api = FakeApi(joined: true);
      final state = await pumpApp(tester, api: api, push: push);
      await tester.runAsync(state.deleteMyData);
      await tester.pumpAndSettle();
      push.opened.add(PushAlert.fromData(_alertData())!);
      await tester.pumpAndSettle();
      // Onboard again and join: the old device's alert does not open.
      await tester.runAsync(() => state.finishOnboarding('en'));
      await tester.pumpAndSettle();
      expect(find.byType(RouteScreen), findsNothing);
    });

    testWidgets('a notification and an invite link: the route, then the join screen on top', (tester) async {
      final push = FakePush()..initial = PushAlert.fromData(_alertData())!;
      final links = StreamController<Uri>();
      links.add(Uri.parse('https://buspilot.org/join#code=DEMO-KOBE-2026'));
      await pumpApp(tester, api: FakeApi(joined: true), push: push, links: links.stream);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join-button')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RouteScreen), findsOneWidget);
      await links.close();
    });

    testWidgets('the notification that started the app opens once it is ready', (tester) async {
      final push = FakePush()..initial = PushAlert.fromData(_alertData())!;
      await pumpApp(tester, api: FakeApi(joined: true), push: push);
      await tester.pumpAndSettle();
      expect(find.byType(RouteScreen), findsOneWidget);
    });

    testWidgets('in the foreground: the text in a snack bar, Show opens the stop', (tester) async {
      phoneSize(tester);
      final push = FakePush();
      final api = FakeApi(joined: true);
      await pumpApp(tester, api: api, push: push);
      final before = api.catalogCalls;
      push.foreground.add(
        PushAlert.fromData(_alertData(), title: 'A Morning route A', body: 'The bus arrives in about 5 min.')!,
      );
      await tester.pump();
      await tester.pumpAndSettle(); // Snack bar in.
      expect(find.text('A Morning route A\nThe bus arrives in about 5 min.'), findsOneWidget);
      expect(api.catalogCalls, greaterThan(before)); // Fresh ETAs.
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.byType(RouteScreen), findsOneWidget);
    });

    testWidgets('an alert for a route the device no longer sees stays on home', (tester) async {
      final push = FakePush();
      await pumpApp(tester, api: FakeApi(joined: true), push: push);
      push.opened.add(PushAlert.fromData(_alertData(patternId: 'gone'))!);
      await tester.pumpAndSettle();
      expect(find.byType(RouteScreen), findsNothing);
      expect(find.text('My stops today'), findsOneWidget);
    });

    testWidgets('channels are created after opt-in, in the app language', (tester) async {
      final push = FakePush();
      final store = await freshStore();
      final notYet = FakePush();
      await pumpApp(tester, api: FakeApi(joined: true), push: notYet, store: store);
      expect(notYet.channels, isEmpty);
      await store.setPushOptedIn();
      final state = await pumpApp(tester, api: FakeApi(joined: true), push: push, store: store);
      expect(push.channels, {
        arrivalAlertsChannel: 'Arrival alerts',
        tripChangesChannel: 'Delays and cancellations',
      });
      await tester.runAsync(() => state.setLanguage('ja'));
      await tester.pumpAndSettle();
      expect(push.channels[arrivalAlertsChannel], '到着のお知らせ');
    });

    test('registers again after the engine cleared the push token', () async {
      final api = FakeApi(joined: true);
      final push = FakePush();
      var now = mondayMorning;
      final store = await freshStore();
      await store.setPushOptedIn();
      final state = AppState(api: api, store: store, push: push, clock: () => now, phoneLanguage: () => 'en');
      await state.start();
      await Future<void>.delayed(Duration.zero);
      expect(api.pushToken, 'fid-123');

      // FCM said UNREGISTERED: the engine cleared device.push_token.
      api.pushToken = null;
      now = now.add(const Duration(hours: 13));
      await state.resumed();
      await Future<void>.delayed(Duration.zero);
      expect(api.pushToken, 'fid-123');
      expect(api.deviceLanguage, 'en');
      state.dispose();
    });
  });

  group('service days and holidays', () {
    test('the server\'s service days win; outside them the calendar rules and holidays', () {
      final raw = demoCatalog()
        ..['service_days'] = [
          {'calendar_id': calendarId, 'service_date': '2026-11-24'},
        ]
        ..['service_days_from'] = '2026-11-01'
        ..['service_days_to'] = '2026-11-30'
        ..['holidays'] = [
          {'date': '2026-11-23', 'name': _labourDay},
          {'date': '2027-02-11', 'name': {'en': 'National Foundation Day'}},
        ];
      final c = Catalog(raw);
      final cal = c.calendars.single;
      expect(c.runsOn(cal, DateTime.utc(2026, 11, 23)), isFalse); // holiday
      expect(c.runsOn(cal, DateTime.utc(2026, 11, 24)), isTrue);
      expect(c.runsOn(cal, DateTime.utc(2026, 11, 25)), isFalse); // not in the list
      // Outside the loaded range: the rules, with the holidays the app knows.
      expect(c.runsOn(cal, DateTime.utc(2027, 2, 10)), isTrue);
      expect(c.runsOn(cal, DateTime.utc(2027, 2, 11)), isFalse);
      expect(c.holidays['2026-11-23']!.resolve('ja'), '勤労感謝の日');
    });

    testWidgets('no bus on a national holiday; the calendar names it', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true)..holidays = {'2026-11-23': _labourDay};
      api.subscriptions.add(_sub(2));
      final state = await pumpApp(tester, api: api);
      expect(api.catalogFrom, DateTime.utc(2026, 11));
      expect(state.catalog.serviceDays[calendarId], isNot(contains('2026-11-23')));
      expect(find.text('No bus today'), findsOneWidget);

      await tester.tap(find.byTooltip('Calendar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('National holidays'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Labour Thanksgiving Day · No bus'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Labour Thanksgiving Day: No bus')), findsOneWidget);
    });
  });

  test('service days load once per range and operators, not with every poll', () async {
    final api = FakeApi(joined: true);
    var now = mondayMorning;
    final state = AppState(api: api, store: await freshStore(), clock: () => now, phoneLanguage: () => 'en');
    await state.refresh();
    await state.refresh();
    expect(api.catalogCalls, 2);
    expect(api.serviceDaysCalls, 1);
    expect(state.catalog.serviceDays[calendarId], contains('2026-11-24'));
    now = now.add(const Duration(hours: 7));
    await state.refresh();
    expect(api.serviceDaysCalls, 2);
    // Staff add a holiday break: the calendar changed, load again at once.
    api.extraExceptions = [
      {'start_date': '2026-11-30', 'end_date': '2026-11-30', 'type': 'removed', 'reason': 'Sports day'},
    ];
    await state.refresh();
    expect(api.serviceDaysCalls, 3);
    expect(state.catalog.serviceDays[calendarId], isNot(contains('2026-11-30')));
    // A new operator (joined, or a followed public route): load again.
    await state.leaveOperator(opId);
    expect(api.serviceDaysCalls, 4);
  });

  test('a calendar without loaded service days uses its own rules', () {
    final raw = demoCatalog()
      ..['service_days'] = const <Json>[]
      ..['service_days_from'] = '2026-11-01'
      ..['service_days_to'] = '2026-11-30'
      ..['service_days_calendars'] = ['another-calendar'];
    final c = Catalog(raw);
    expect(c.runsOn(c.calendars.single, DateTime.utc(2026, 11, 24)), isTrue);
    final covered = Catalog({...raw, 'service_days_calendars': [calendarId]});
    expect(covered.runsOn(covered.calendars.single, DateTime.utc(2026, 11, 24)), isFalse);
  });

  testWidgets('a foreground alert before start or after delete does not refresh', (tester) async {
    final push = FakePush();
    final api = FakeApi(joined: true);
    final state = await pumpApp(tester, api: api, push: push);
    await tester.runAsync(state.deleteMyData);
    await tester.pumpAndSettle();
    final before = api.catalogCalls;
    push.foreground.add(PushAlert.fromData(_alertData(), title: 'T', body: 'B')!);
    await tester.pumpAndSettle();
    expect(api.catalogCalls, before);
    expect(find.text('T\nB'), findsNothing);
  });

  group('post categories', () {
    Json post(String id, String category, String title, String at) => {
      'id': id,
      'operator_id': opId,
      'route_id': null,
      'category': category,
      'title': {'en': title},
      'body': {'en': 'Body of $title'},
      'published_at': at,
    };

    testWidgets('shows the category; hidden categories stay hidden on this phone', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true)
        ..posts = [
          post('p1', 'cancellation', 'No bus on Friday', '2026-11-22T10:00:00Z'),
          post('p2', 'general', 'Lost and found', '2026-11-22T09:00:00Z'),
          post('p3', 'unknown-later', 'Something new', '2026-11-22T08:00:00Z'),
        ];
      final state = await pumpApp(tester, api: api);
      expect(state.unreadPosts, 3);

      await tester.tap(find.byTooltip('News'));
      await tester.pumpAndSettle();
      expect(find.text('Cancellation'), findsOneWidget);
      // Unknown categories count as general.
      expect(find.text('General'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('news-categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-general')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // Close the sheet.
      await tester.pumpAndSettle();

      expect(find.text('No bus on Friday'), findsOneWidget);
      expect(find.text('Lost and found'), findsNothing);
      expect(find.text('2 announcements hidden'), findsOneWidget);
      expect(state.store.hiddenCategories, {PostCategory.general});
      expect(state.shownPosts.map((p) => p.id), ['p1']);
    });

    test('hidden categories do not count as unread', () async {
      final api = FakeApi(joined: true)
        ..posts = [post('p1', 'general', 'Lost and found', '2026-11-22T09:00:00Z')];
      final state = AppState(
        api: api,
        store: await freshStore(),
        clock: () => mondayMorning,
        phoneLanguage: () => 'en',
      );
      await state.refresh();
      expect(state.unreadPosts, 1);
      await state.setCategoryHidden(PostCategory.general, true);
      expect(state.unreadPosts, 0);
    });
  });

  group('mini map', () {
    Future<void> openStop(WidgetTester tester, int seq) async {
      await tester.tap(find.text('Morning route A'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('stop-$seq')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    testWidgets('a stop not followed: follow it to see a map', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true);
      await pumpApp(tester, api: api, mapStyleUrl: 'https://tiles.example/style.json');
      await openStop(tester, 3);
      expect(api.calls, contains('mapData:s3'));
      expect(find.text('Stops you follow can show on a small map, at most two per bus service.'), findsOneWidget);
    });

    testWidgets('a followed stop without a location: the two-stop limit', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true)..stopLocations = {'s1': const LngLat(135.19, 34.70)};
      api.subscriptions.add(_sub(3));
      await pumpApp(tester, api: api, mapStyleUrl: 'https://tiles.example/style.json');
      await openStop(tester, 3);
      expect(
        find.textContaining('No map for this stop. A small map shows at most two stops'),
        findsOneWidget,
      );
    });

    testWidgets('no maps in this build: no request, no note', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true);
      await pumpApp(tester, api: api);
      await openStop(tester, 3);
      expect(api.calls.where((c) => c.startsWith('mapData')), isEmpty);
      expect(find.byKey(const Key('mini-map-note')), findsNothing);
    });
  });

  group('live trips', () {
    testWidgets('shown on home with the next stop; follow a stop of the trip', (tester) async {
      phoneSize(tester);
      final push = FakePush();
      final api = FakeApi(joined: true)..liveTrips = [liveTrip()];
      final state = await pumpApp(tester, api: api, push: push);
      expect(find.text('Extra trips'), findsOneWidget);
      expect(find.text('Museum tour'), findsOneWidget);
      expect(find.textContaining('Next: Shin-Kobe Station'), findsOneWidget);

      await tester.tap(find.text('Museum tour'));
      await tester.pumpAndSettle();
      expect(find.byType(LiveTripScreen), findsOneWidget);
      expect(find.text('Sannomiya'), findsOneWidget);
      expect(find.text('10:20'), findsOneWidget); // planned arrival
      expect(find.text('Shown until 21:00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('live-stop-2')));
      await tester.pumpAndSettle();
      // No alerts for live trips yet: no alert settings, no push prompt.
      expect(find.textContaining('Alerts for extra trips are not sent yet'), findsOneWidget);
      expect(find.text('Minutes away'), findsNothing);
      await tester.tap(find.byKey(const Key('save-alert')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(api.calls, contains('saveSubscription:live-12'));
      final sub = state.catalog.subscriptions.single;
      expect(sub.tripInstanceId, 'live-1');
      expect(sub.patternId, isNull);
      expect(push.permissionRequests, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();
      // On home: a card for the followed stop of the trip.
      expect(find.byKey(const ValueKey('live-1:2')), findsOneWidget);
    });

    testWidgets('ETA from the stop event; hidden after visible_until', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true)
        ..liveTrips = [
          liveTrip(status: 'active', events: [event(1, 'departed', arrived: kobe(7, 30), departed: kobe(7, 31)), event(2, 'upcoming', eta: kobe(7, 52))]),
          liveTrip(id: 'live-old', visibleUntil: '2026-11-22T22:00:00Z'),
        ];
      api.subscriptions.add({..._sub(2), 'id': 'sub-live', 'pattern_id': null, 'trip_instance_id': 'live-1'});
      final state = await pumpApp(tester, api: api);
      expect(state.liveTrips.map((t) => t.id), ['live-1']);
      // Planned 10:20, ETA 07:52: early, so "in 12 min".
      expect(find.text('07:52 · in 12 min'), findsWidgets);
    });

    testWidgets('a followed stop of an ended trip: "trip ended" and unfollow', (tester) async {
      phoneSize(tester);
      final api = FakeApi(joined: true)
        ..liveTrips = [liveTrip(visibleUntil: '2026-11-22T22:00:00Z')];
      api.subscriptions.add({..._sub(2), 'id': 'sub-live', 'pattern_id': null, 'trip_instance_id': 'live-1'});
      await pumpApp(tester, api: api);
      expect(find.text('An extra trip you followed has ended'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Stop following'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(api.subscriptions, isEmpty);
      expect(find.text('An extra trip you followed has ended'), findsNothing);
    });

    testWidgets('a tapped alert for a live trip opens it at the stop', (tester) async {
      final push = FakePush();
      final api = FakeApi(joined: true)..liveTrips = [liveTrip()];
      await pumpApp(tester, api: api, push: push);
      push.opened.add(PushAlert.fromData(_alertData(patternId: '', tripInstanceId: 'live-1', seq: '2'))!);
      await tester.pumpAndSettle();
      final screen = tester.widget<LiveTripScreen>(find.byType(LiveTripScreen));
      expect(screen.highlightSequence, 2);
    });
  });

  testWidgets('delete my data calls delete_my_device', (tester) async {
    final api = FakeApi(joined: true);
    final state = await pumpApp(tester, api: api);
    await tester.runAsync(state.deleteMyData);
    expect(api.calls, contains('deleteMyDevice'));
  });
}
