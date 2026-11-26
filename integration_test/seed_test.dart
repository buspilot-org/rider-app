// End-to-end test against the local Supabase stack with the seed of
// buspilot-org/server: join with DEMO-KOBE-2026 (routes from rpc/my_routes,
// service days from rpc/service_days), follow a stop, see it on home, delete
// my data (rpc/delete_my_device). Run on a device or emulator (see README):
//
//   adb reverse tcp:55321 tcp:55321
//   flutter test integration_test -d <device> --dart-define-from-file=config/local.json
import 'package:buspilot_rider/src/app.dart';
import 'package:buspilot_rider/src/config.dart';
import 'package:buspilot_rider/src/data/supabase_api.dart';
import 'package:buspilot_rider/src/state/app_state.dart';
import 'package:buspilot_rider/src/state/local_store.dart';
import 'package:buspilot_rider/src/ui/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

/// Pumps until [finder] matches (network calls take real time).
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = [
    for (final e in find.byType(Text).evaluate()) (e.widget as Text).data,
  ];
  throw TestFailure('Timed out waiting for $finder; on screen: $texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('join, follow a stop, see it on home, delete my data', (tester) async {
    expect(AppConfig.isConfigured, isTrue, reason: 'build with --dart-define-from-file');
    tzdata.initializeTimeZones();
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    // A fresh anonymous device every run. The client restores a stored
    // session (from an earlier run of the app with the same package id) in
    // the background; let that finish before signing out.
    final auth = Supabase.instance.client.auth;
    await auth.onAuthStateChange.first.timeout(const Duration(seconds: 5), onTimeout: () => AuthState(AuthChangeEvent.initialSession, null));
    await auth.signOut();
    expect(auth.currentUser, isNull);
    final store = await LocalStore.open();
    await store.clear();

    final api = SupabaseApi(Supabase.instance.client);
    final state = AppState(api: api, store: store);
    await tester.pumpWidget(RiderApp(state: state));
    await state.start();
    await pumpUntil(tester, find.byKey(const Key('lang-en')));

    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('language-continue')));
    await pumpUntil(tester, find.text('No bus services yet'));
    final userId = Supabase.instance.client.auth.currentUser!.id;

    await tester.tap(find.text('Join a bus service'));
    await pumpUntil(tester, find.byKey(const Key('invite-code')));
    await tester.enterText(find.byKey(const Key('invite-code')), 'DEMO-KOBE-2026');
    await tester.tap(find.byKey(const Key('join-button')));
    await pumpUntil(tester, find.text('Morning route A'));
    // rpc/my_routes: the operator's route only; service days and holidays
    // for about 13 months from this month.
    expect(state.catalog.routes.map((r) => r.id), ['d0000000-0000-4000-8000-000000000101']);
    expect(state.catalog.serviceDaysFrom, isNotNull);
    expect(state.catalog.serviceDays.values.expand((d) => d), isNotEmpty);
    expect(state.catalog.holidays, isNotEmpty);

    // Let the join screen close before tapping home.
    await pumpUntil(tester, find.text('Routes').hitTestable());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Morning route A').hitTestable());
    await pumpUntil(tester, find.byKey(const ValueKey('stop-2')));
    await tester.tap(find.byKey(const ValueKey('stop-2')));
    await pumpUntil(tester, find.byKey(const Key('save-alert')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-alert')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('save-alert')));
    await pumpUntil(tester, find.text('Stop followed'));

    await tester.pageBack();
    await pumpUntil(tester, find.byType(StopCard));
    expect(
      find.descendant(of: find.byType(StopCard), matching: find.text('Kitano-zaka')),
      findsOneWidget,
    );

    // The server has the subscription, for this device only.
    final rows = await Supabase.instance.client.from('subscription').select();
    expect(rows, hasLength(1));
    expect(rows.single['stop_sequence'], 2);
    expect(rows.single['device_id'], userId);

    // Delete my data from settings: rpc/delete_my_device, then sign out.
    await tester.tap(find.byTooltip('Settings'));
    await pumpUntil(tester, find.text('Delete my data'));
    await tester.scrollUntilVisible(
      find.text('Delete my data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete my data'));
    await pumpUntil(tester, find.widgetWithText(FilledButton, 'Delete'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await pumpUntil(tester, find.byKey(const Key('lang-en')));
    expect(Supabase.instance.client.auth.currentUser, isNull);

    // The anonymous user is gone: a new device does not see the old
    // subscription, and the old one cannot sign back in with its session.
    await Supabase.instance.client.auth.signInAnonymously();
    expect(Supabase.instance.client.auth.currentUser!.id, isNot(userId));
    final after = await Supabase.instance.client.from('subscription').select();
    expect(after, isEmpty);
    await Supabase.instance.client.rpc('delete_my_device');
    await Supabase.instance.client.auth.signOut();
  });
}
