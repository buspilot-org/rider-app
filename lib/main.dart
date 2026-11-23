import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

import 'src/app.dart';
import 'src/config.dart';
import 'src/data/supabase_api.dart';
import 'src/push/fcm_push_service.dart';
import 'src/push/push_service.dart';
import 'src/state/app_state.dart';
import 'src/state/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const NotConfiguredApp());
    return;
  }
  tzdata.initializeTimeZones();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
    debug: false,
    // No auth deep links (anonymous sign-in only). Otherwise the Supabase
    // client would also read the link that opened the app.
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  final state = AppState(
    api: SupabaseApi(Supabase.instance.client),
    store: await LocalStore.open(),
    // iOS has no Firebase configuration yet.
    push: Platform.isAndroid ? await FcmPushService.create() : const NoPushService(),
    platform: Platform.isIOS ? 'ios' : 'android',
  );
  final appLinks = AppLinks();
  // The link that started the app, then links while it runs.
  final links = () async* {
    final initial = await appLinks.getInitialLink();
    if (initial != null) yield initial;
    yield* appLinks.uriLinkStream;
  }();
  runApp(RiderApp(state: state, links: links));
  unawaited(state.start());
}
