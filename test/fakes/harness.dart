import 'package:buspilot_rider/src/app.dart';
import 'package:buspilot_rider/src/push/push_service.dart';
import 'package:buspilot_rider/src/state/app_state.dart';
import 'package:buspilot_rider/src/state/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

import 'fake_api.dart';

/// Monday 2026-11-23 07:40 in Kobe.
final mondayMorning = DateTime.utc(2026, 11, 22, 22, 40);

void initTimeZones() => tzdata.initializeTimeZones();

Future<LocalStore> freshStore({bool onboarded = true, String? language = 'en'}) async {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  final store = await LocalStore.open();
  if (onboarded) await store.setOnboarded();
  await store.setLanguage(language);
  return store;
}

/// Starts the app on [api] with a fixed clock and waits until it settles.
Future<AppState> pumpApp(
  WidgetTester tester, {
  required FakeApi api,
  DateTime? now,
  LocalStore? store,
  bool onboarded = true,
  String? language = 'en',
  Stream<Uri>? links,
  PushService? push,
  String mapStyleUrl = '',
}) async {
  final s = store ?? await freshStore(onboarded: onboarded, language: language);
  var clock = now ?? mondayMorning;
  final state = AppState(
    api: api,
    store: s,
    clock: () => clock,
    phoneLanguage: () => 'en',
    push: push ?? const NoPushService(),
    mapStyleUrl: mapStyleUrl,
  );
  await tester.pumpWidget(RiderApp(state: state, links: links));
  await tester.runAsync(state.start);
  await tester.pumpAndSettle();
  return state;
}
