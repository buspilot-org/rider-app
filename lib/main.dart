import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

import 'src/app.dart';
import 'src/config.dart';
import 'src/data/supabase_api.dart';
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
  );
  final state = AppState(
    api: SupabaseApi(Supabase.instance.client),
    store: await LocalStore.open(),
    platform: Platform.isIOS ? 'ios' : 'android',
  );
  runApp(RiderApp(state: state, links: AppLinks().uriLinkStream));
  unawaited(state.start());
}
