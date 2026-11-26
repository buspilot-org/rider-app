import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'data/invite_link.dart';
import 'l10n/app_localizations.dart';
import 'push/push_alert.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/join_screen.dart';
import 'ui/language_screen.dart';
import 'ui/live_trip_screen.dart';
import 'ui/route_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

class RiderApp extends StatefulWidget {
  const RiderApp({super.key, required this.state, this.links});

  final AppState state;

  /// Invite links opened while the app runs (and the one that started it).
  final Stream<Uri>? links;

  @override
  State<RiderApp> createState() => _RiderAppState();
}

class _RiderAppState extends State<RiderApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<PushAlert>? _foregroundSub;
  StreamSubscription<PushAlert>? _openedSub;
  String? _pendingCode;

  /// A tapped notification, opened once the app is ready.
  PushAlert? _pendingAlert;
  Uri? _lastUri;
  DateTime? _lastAt;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.addListener(_maybeOpenPending);
    _linkSub = widget.links?.listen(_onLink);
    final push = state.push;
    _foregroundSub = push.foregroundAlerts.listen(_onForegroundAlert);
    _openedSub = push.openedAlerts.listen(_onOpenedAlert);
    push.initialAlert().then((a) {
      if (a != null && mounted) _onOpenedAlert(a);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.removeListener(_maybeOpenPending);
    _linkSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) state.resumed();
  }

  void _onLink(Uri uri) {
    final code = inviteCodeFrom(uri.toString());
    // uriLinkStream may repeat the initial link right away; a later tap on
    // the same link opens the join screen again.
    final now = DateTime.now();
    if (code == null ||
        (uri == _lastUri && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 3))) {
      return;
    }
    _lastUri = uri;
    _lastAt = now;
    _pendingCode = code;
    _maybeOpenPending();
  }

  /// The system shows nothing while the app is in the foreground: show the
  /// server's text in a snack bar with a button to the stop, and refresh.
  void _onForegroundAlert(PushAlert alert) {
    unawaited(state.refresh());
    final context = _navigator.currentContext;
    final messenger = _messenger.currentState;
    final text = [?alert.title, ?alert.body].join('\n');
    if (context == null || messenger == null || text.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: AppLocalizations.of(context).alertShow,
            onPressed: () => _onOpenedAlert(alert),
          ),
        ),
      );
  }

  void _onOpenedAlert(PushAlert alert) {
    _pendingAlert = alert;
    _maybeOpenPending();
  }

  /// Opens the route (or live trip) of a notification at its stop. Loads
  /// fresh data first when the catalog does not have it yet (the app was
  /// started from the notification, or the trip is new).
  Future<void> _openAlert(PushAlert alert) async {
    Widget? screen() {
      final catalog = state.catalog;
      final seq = alert.stopSequence;
      if (alert.patternId case final patternId?) {
        final found = catalog.pattern(patternId);
        if (found == null) return null;
        return RouteScreen(
          routeId: found.$1.id,
          patternId: patternId,
          highlightSequence: seq,
          tripInstanceId: alert.tripInstanceId,
        );
      }
      if (alert.tripInstanceId case final tripId?) {
        if (state.liveTrip(tripId) == null) return null;
        return LiveTripScreen(tripInstanceId: tripId, highlightSequence: seq);
      }
      return null;
    }

    var target = screen();
    if (target == null) {
      await state.refresh();
      target = screen();
    }
    if (target == null) return; // Not visible any more: stay on home.
    final page = target;
    await _navigator.currentState?.push(MaterialPageRoute(builder: (_) => page));
  }

  /// Opens the join screen for a link, or the stop of a tapped
  /// notification, once the app is ready (after the language was chosen and
  /// the device signed in).
  void _maybeOpenPending() {
    final nav = _navigator.currentState;
    if (nav == null || state.startup != StartupState.ready) return;
    final alert = _pendingAlert;
    if (alert != null) {
      _pendingAlert = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAlert(alert));
      WidgetsBinding.instance.scheduleFrame();
    }
    final code = _pendingCode;
    if (code == null) return;
    _pendingCode = null;
    // After the frame that shows home, so the join screen lands on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigator.currentState?.push(
        MaterialPageRoute(builder: (_) => JoinScreen(initialCode: code)),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final chosen = state.chosenLanguage;
          return MaterialApp(
            navigatorKey: _navigator,
            scaffoldMessengerKey: _messenger,
            onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            locale: chosen == null ? null : Locale(chosen),
            supportedLocales: AppLocalizations.supportedLocales,
            // Not AppLocalizations.localizationsDelegates: the generated list
            // still uses the Material and Cupertino localizations of
            // flutter_localizations, which material_ui does not read.
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supported) {
              for (final s in supported) {
                if (s.languageCode == locale?.languageCode) return s;
              }
              return const Locale('en');
            },
            // One root route that switches its content: replacing `home`
            // would reset the navigator and drop a join screen opened from
            // an invite link meanwhile.
            home: const _Root(),
          );
        },
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => switch (AppScope.of(context).startup) {
    StartupState.loading => const _Splash(),
    StartupState.chooseLanguage => const LanguageScreen(onboarding: true),
    StartupState.offlineNoData => const _OfflineStart(),
    StartupState.ready => const HomeScreen(),
  };
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _OfflineStart extends StatelessWidget {
  const _OfflineStart();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 16),
              Text(l.startOfflineTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(l.startOfflineBody, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => AppScope.read(context).retry(),
                child: Text(l.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the build has no server configured.
class NotConfiguredApp extends StatelessWidget {
  const NotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Buspilot: no server configured.\n'
            'Build with --dart-define-from-file=config/local.json '
            '(see README).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
