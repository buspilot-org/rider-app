import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'data/invite_link.dart';
import 'l10n/app_localizations.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/join_screen.dart';
import 'ui/language_screen.dart';
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
  StreamSubscription<Uri>? _linkSub;
  String? _pendingCode;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.addListener(_maybeOpenPending);
    _linkSub = widget.links?.listen(_onLink);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.removeListener(_maybeOpenPending);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) state.resumed();
  }

  void _onLink(Uri uri) {
    final code = inviteCodeFrom(uri.toString());
    if (code == null) return;
    _pendingCode = code;
    _maybeOpenPending();
  }

  /// Opens the join screen for a link once the app is ready (after the
  /// language was chosen and the device signed in).
  void _maybeOpenPending() {
    final code = _pendingCode;
    final nav = _navigator.currentState;
    if (code == null || nav == null || state.startup != StartupState.ready) return;
    _pendingCode = null;
    nav.push(MaterialPageRoute(builder: (_) => JoinScreen(initialCode: code)));
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
            home: switch (state.startup) {
              StartupState.loading => const _Splash(),
              StartupState.chooseLanguage => const LanguageScreen(onboarding: true),
              StartupState.offlineNoData => const _OfflineStart(),
              StartupState.ready => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
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
