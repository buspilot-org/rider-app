import 'dart:async';

import 'package:buspilot_rider/src/data/models.dart';
import 'package:buspilot_rider/src/push/push_service.dart';
import 'package:buspilot_rider/src/state/app_state.dart';
import 'package:buspilot_rider/src/state/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';
import 'fakes/fake_push.dart';
import 'fakes/harness.dart';

/// A phone-sized screen, so the whole alert settings form fits.
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(initTimeZones);

  testWidgets('no push registration before the user opts in, even if the OS allows', (tester) async {
    phoneSize(tester);
    final api = FakeApi(joined: true);
    final push = FakePush(osAllowed: true);
    await pumpApp(tester, api: api, push: push);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(push.tokenCalls, 0);
    expect(api.calls.where((c) => c.startsWith('pushToken')), isEmpty);

    // Follow a stop: explanation first, then the OS prompt, then the token.
    await tester.tap(find.text('Morning route A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stop-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alert')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Get alerts for this stop?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
    expect(push.permissionRequests, 1);
    expect(api.calls, contains('pushToken:fid-123'));
  });

  testWidgets('"Not now" stores nothing', (tester) async {
    phoneSize(tester);
    final api = FakeApi(joined: true);
    final push = FakePush(osAllowed: false);
    final state = await pumpApp(tester, api: api, push: push);
    await tester.tap(find.text('Morning route A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stop-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alert')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(push.permissionRequests, 0);
    expect(state.store.pushOptedIn, isFalse);
    expect(api.calls.where((c) => c.startsWith('pushToken')), isEmpty);
  });

  AppState plainState(FakeApi api, LocalStore store, {PushService? push}) => AppState(
    api: api,
    store: store,
    clock: () => mondayMorning,
    phoneLanguage: () => 'en',
    push: push ?? const NoPushService(),
  );

  test('a refresh requested during another one runs again afterwards', () async {
    final api = FakeApi(joined: true);
    final state = plainState(api, await freshStore());
    api.catalogGate = Completer<void>();
    final first = state.refresh();
    // A stop followed meanwhile.
    api.subscriptions.add({
      'id': 'sub-4', 'operator_id': opId, 'pattern_id': patternId, 'stop_sequence': 4,
      'trigger': 'minutes', 'trigger_value': 5, 'notify_passed': false, 'muted_until': null,
    });
    final second = state.refresh();
    api.catalogGate!.complete();
    await Future.wait([first, second]);
    expect(api.catalogCalls, 2);
    expect(state.catalog.subscriptions.map((s) => s.stopSequence), [4]);
  });

  test('delete my data during a refresh does not bring data back', () async {
    final api = FakeApi(joined: true);
    final push = FakePush();
    final state = plainState(api, await freshStore(), push: push);
    api.catalogGate = Completer<void>();
    final r = state.refresh();
    final d = state.deleteMyData();
    api.catalogGate!.complete();
    await Future.wait([r, d]);
    expect(state.catalog.routes, isEmpty);
    expect(state.fetchedAt, isNull);
    expect(state.store.readCache(), isNull);
    expect(push.unregisters, 1);
  });

  testWidgets('the same invite link opens the join screen again later', (tester) async {
    final api = FakeApi(joined: true);
    final links = StreamController<Uri>();
    await pumpApp(tester, api: api, links: links.stream);
    final link = Uri.parse('https://buspilot.org/join/DEMO-KOBE-2026');
    links.add(link);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-button')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-button')), findsNothing);

    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    links.add(link);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-button')), findsOneWidget);
    await links.close();
  });

  test('visibleCatalog keeps the operator and calendar of a followed public route', () {
    final raw = demoCatalog(member: false, subscriptions: [
      {'id': 's', 'operator_id': opId, 'pattern_id': patternId, 'stop_sequence': 1},
    ]);
    final c = Catalog(visibleCatalog(raw));
    expect(c.routes.map((r) => r.id), [routeId]);
    expect(c.operators.map((o) => o.id), [opId]);
    expect(c.calendars.map((x) => x.id), [calendarId]);
    // Posts are filtered by RLS on the server (general posts for members
    // only), not here.
    final withPost = demoCatalog(member: false, subscriptions: [
      {'id': 's', 'operator_id': opId, 'pattern_id': patternId, 'stop_sequence': 1},
    ])..['posts'] = [
        {'id': 'r1', 'operator_id': opId, 'route_id': routeId, 'published_at': '2026-11-23T00:00:00Z'},
      ];
    expect(Catalog(visibleCatalog(withPost)).posts.map((p) => p.id), ['r1']);

    final none = Catalog(visibleCatalog(demoCatalog(member: false)));
    expect(none.routes, isEmpty);
    expect(none.calendars, isEmpty);
  });
}
