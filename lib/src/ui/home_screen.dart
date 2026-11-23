import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/arrivals.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'alert_settings_screen.dart';
import 'calendar_screen.dart';
import 'join_screen.dart';
import 'news_screen.dart';
import 'route_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// Refreshes the app state every [interval] while the screen is shown and
/// the app is in the foreground. Realtime comes later.
mixin Polling<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  Duration get interval => const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(interval, (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final isTop = ModalRoute.of(context)?.isCurrent ?? true;
      if (mounted && isTop && (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        AppScope.read(context).refresh();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with Polling {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final catalog = state.catalog;
    final now = state.clock();
    final unread = state.unreadPosts;

    final cards = <({Subscription sub, BusRoute route, TripPattern pattern, NextArrival next})>[];
    for (final sub in catalog.subscriptions) {
      final found = catalog.pattern(sub.patternId);
      if (found == null) continue;
      final (route, pattern) = found;
      cards.add((
        sub: sub,
        route: route,
        pattern: pattern,
        next: nextArrival(
          catalog: catalog,
          route: route,
          pattern: pattern,
          sequence: sub.stopSequence,
          instances: state.instances,
          now: now,
        ),
      ));
    }
    // Soonest first; stops without a bus today last.
    cards.sort((a, b) {
      final ta = a.next.next?.time;
      final tb = b.next.next?.time;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });

    final hasRoutes = catalog.routes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            tooltip: l.newsTitle,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.campaign_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewsScreen()),
            ),
          ),
          IconButton(
            tooltip: l.calendarTitle,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: hasRoutes
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  )
                : null,
          ),
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            const UpdatedLine(),
            if (!hasRoutes) const _EmptyState(),
            if (hasRoutes) ...[
              _Header(l.myStops),
              if (cards.isEmpty)
                _HintCard(title: l.homeNoStopsTitle, body: l.homeNoStopsBody),
              for (final c in cards)
                StopCard(
                  key: ValueKey('${c.sub.patternId}:${c.sub.stopSequence}'),
                  subscription: c.sub,
                  route: c.route,
                  pattern: c.pattern,
                  next: c.next,
                  now: now,
                ),
              _Header(l.routesHeader),
              ..._routeTiles(context, catalog),
            ],
          ],
        ),
      ),
      floatingActionButton: hasRoutes
          ? FloatingActionButton.extended(
              onPressed: () => openJoin(context),
              icon: const Icon(Icons.add),
              label: Text(l.addService),
            )
          : null,
    );
  }

  List<Widget> _routeTiles(BuildContext context, Catalog catalog) {
    final tiles = <Widget>[];
    for (final op in catalog.operators) {
      final routes = catalog.routes.where((r) => r.operatorId == op.id).toList();
      if (routes.isEmpty) continue;
      for (final r in routes) {
        tiles.add(
          ListTile(
            leading: OperatorAvatar(operator: op),
            title: Text(r.name.resolve(context.lang)),
            subtitle: Text(op.name.resolve(context.lang)),
            trailing: RouteBadge(route: r),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RouteScreen(routeId: r.id)),
            ),
          ),
        );
      }
    }
    return tiles;
  }
}

Future<void> openJoin(BuildContext context, {String? code}) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JoinScreen(initialCode: code)),
    );

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.touch_app_outlined),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.directions_bus_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(l.homeEmptyTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l.homeEmptyBody, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => openJoin(context),
            icon: const Icon(Icons.qr_code),
            label: Text(l.joinTitle),
          ),
        ],
      ),
    );
  }
}

/// One followed stop: operator, route, stop and the next arrival.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.subscription,
    required this.route,
    required this.pattern,
    required this.next,
    required this.now,
  });

  final Subscription subscription;
  final BusRoute route;
  final TripPattern pattern;
  final NextArrival next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final op = state.catalog.operator(route.operatorId);
    final stop = pattern.stopAt(subscription.stopSequence);
    final visit = next.next;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final important = visit?.kind == VisitKind.cancelled || visit?.kind == VisitKind.delayed;
    final offRoute = visit?.instance?.offRouteSince;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RouteScreen(
              routeId: route.id,
              patternId: pattern.id,
              highlightSequence: subscription.stopSequence,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OperatorAvatar(operator: op, radius: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      op?.name.resolve(context.lang) ?? '',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  RouteBadge(route: route),
                  IconButton(
                    tooltip: l.alertSettings,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      subscription.isMuted(now)
                          ? Icons.notifications_paused_outlined
                          : Icons.notifications_outlined,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlertSettingsScreen(
                          patternId: pattern.id,
                          stopSequence: subscription.stopSequence,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                stop?.stopName.resolve(context.lang) ?? '',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    visitIcon(visit?.kind),
                    color: important ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visitText(context, visit, op, now),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: important ? scheme.error : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (visit != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    phaseText(context, visit.tripPhase),
                    if (visit.trip != null)
                      l.tripAt(formatTime(
                        atOffset(
                          locationOf(op),
                          serviceDay(locationOf(op), now),
                          visit.trip!.startTime,
                        ),
                        op,
                      )),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (offRoute != null)
                Text(
                  l.positionUnknownSince(formatTime(offRoute, op)),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              if (subscription.isMuted(now))
                Text(
                  l.alertPausedThrough(formatPausedThrough(subscription.mutedUntil!, op, context.lang)),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
