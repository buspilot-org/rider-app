import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

void main() {
  setUpAll(initTimeZones);

  testWidgets('first start: language, then join with a code', (tester) async {
    final api = FakeApi();
    final state = await pumpApp(tester, api: api, onboarded: false, language: null);

    // Language first, nothing on the server yet.
    expect(find.text('Choose your language'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tester.tap(find.byKey(const Key('lang-de')));
    await tester.pumpAndSettle();
    expect(find.text('Sprache wählen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-continue')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(api.calls, containsAllInOrder(['signIn', 'touchDevice', 'catalog']));
    expect(api.deviceLanguage, 'en');
    expect(state.store.onboarded, isTrue);
    expect(find.text('No bus services yet'), findsOneWidget);

    await tester.tap(find.text('Join a bus service'));
    await tester.pumpAndSettle();

    // A wrong code.
    await tester.enterText(find.byKey(const Key('invite-code')), 'WRONG-CODE1');
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('This code is not valid. Check it and try again.'), findsOneWidget);

    // The demo code, typed in lower case without the dash.
    await tester.enterText(find.byKey(const Key('invite-code')), 'demokobe2026');
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(api.calls, contains('redeem:DEMOKOBE2026'));
    expect(find.text('Joined Kitano Demo International School'), findsOneWidget);
    expect(find.text('Morning route A'), findsOneWidget);
    expect(find.text('Follow your stop'), findsOneWidget);
  });

  testWidgets('an invite link opens the join screen and redeems', (tester) async {
    final api = FakeApi();
    final links = StreamController<Uri>();
    final store = await freshStore();
    final state = await pumpApp(tester, api: api, store: store, links: links.stream);

    links.add(Uri.parse('https://buspilot.org/join/DEMO-KOBE-2026'));
    await tester.pumpAndSettle();
    // The link fills in the code; joining needs a tap.
    expect(find.text('DEMO-KOBE-2026'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('redeem')), isEmpty);
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(api.calls, contains('redeem:DEMO-KOBE-2026'));
    expect(state.catalog.memberOperatorIds, {opId});
    expect(find.text('Morning route A'), findsOneWidget);
    await links.close();
  });

  testWidgets('an invite link opened on first start waits for the language', (tester) async {
    final api = FakeApi();
    final links = StreamController<Uri>();
    await pumpApp(tester, api: api, onboarded: false, language: null, links: links.stream);
    links.add(Uri.parse('https://buspilot.org/join/DEMO-KOBE-2026'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-continue')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-KOBE-2026'), findsOneWidget);
    expect(find.byKey(const Key('join-button')), findsOneWidget);
    await links.close();
  });

  testWidgets('other operators\' public routes and posts stay hidden', (tester) async {
    final api = FakeApi(joined: true)..withForeignPublicRoute = true;
    final state = await pumpApp(tester, api: api);
    expect(find.text('Morning route A'), findsOneWidget);
    expect(find.text('Hotel shuttle'), findsNothing);
    expect(state.catalog.posts.map((p) => p.id), ['p1']);

    // Not a member of anything: the join prompt, not the hotel's route.
    final visitor = FakeApi()..withForeignPublicRoute = true;
    await pumpApp(tester, api: visitor);
    expect(find.text('No bus services yet'), findsOneWidget);
  });

  testWidgets('server error on start: cache if any, else retry screen', (tester) async {
    final api = FakeApi(joined: true)..serverError = StateError('503');
    await pumpApp(tester, api: api);
    expect(find.text('Try again'), findsOneWidget);

    final store = await freshStore();
    await pumpApp(tester, api: FakeApi(joined: true), store: store);
    final failing = FakeApi(joined: true)..serverError = StateError('503');
    await pumpApp(tester, api: failing, store: store);
    expect(find.text('Morning route A'), findsOneWidget);
    expect(find.textContaining('Not updated · as of'), findsOneWidget);
  });

  testWidgets('leave an operator from settings', (tester) async {
    final api = FakeApi(joined: true);
    await pumpApp(tester, api: api);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Kitano Demo International School?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(api.calls, contains('leave:$opId'));
  });

  testWidgets('delete my data starts over', (tester) async {
    final api = FakeApi(joined: true);
    final state = await pumpApp(tester, api: api);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete my data'), 100);
    await tester.tap(find.text('Delete my data'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(api.deviceDeleted, isTrue);
    expect(state.store.onboarded, isFalse);
    expect(state.store.readCache(), isNull);
    expect(find.text('Choose your language'), findsOneWidget);
  });
}
