import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/arrivals.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'alert_settings_screen.dart';
import 'calendar_screen.dart';
import 'join_screen.dart';
import 'live_trip_screen.dart';
import 'news_screen.dart';
import 'route_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Refreshes the app state every [interval] while the screen is shown and
/// the app is in the foreground. The engine's Live API replaces polling
/// later, behind [LiveSource].
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

    final cards = <StopCard>[];
    // Followed stops of live trips that are no longer shown (ended, or no
    // longer visible to this device): the server keeps the subscription
    // (and its mini map place), so offer to unfollow. Not while the data is
    // stale: the trip may just be missing from an old cache.
    final stale = state.offline || state.serverError;
    final ended = <Subscription>[];
    for (final sub in catalog.subscriptions) {
      if (sub.patternId case final patternId?) {
        final found = catalog.pattern(patternId);
        if (found == null) continue;
        final (route, pattern) = found;
        cards.add(StopCard(
          key: ValueKey('$patternId:${sub.stopSequence}'),
          subscription: sub,
          operatorId: route.operatorId,
          route: route,
          stopName: pattern.stopAt(sub.stopSequence)?.stopName.resolve(context.lang) ?? '',
          next: nextArrival(
            catalog: catalog,
            route: route,
            pattern: pattern,
            sequence: sub.stopSequence,
            instances: state.instances,
            now: now,
          ),
          now: now,
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RouteScreen(
                routeId: route.id,
                patternId: pattern.id,
                highlightSequence: sub.stopSequence,
              ),
            ),
          ),
        ));
      } else if (sub.tripInstanceId case final tripId?) {
        // A stop of a live trip: shown while the trip is.
        final trip = state.liveTrip(tripId);
        if (trip == null || trip.operatorId == null) {
          if (!stale) ended.add(sub);
          continue;
        }
        final visit = liveVisitAt(trip, sub.stopSequence, now);
        cards.add(StopCard(
          key: ValueKey('$tripId:${sub.stopSequence}'),
          subscription: sub,
          operatorId: trip.operatorId!,
          route: trip.routeId == null ? null : catalog.route(trip.routeId!),
          stopName: trip.plannedStopAt(sub.stopSequence)?.stopName.resolve(context.lang) ?? '',
          tripTitle: liveTripTitle(context, trip),
          next: NextArrival(next: visit, visits: [?visit]),
          now: now,
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LiveTripScreen(
                tripInstanceId: trip.id,
                highlightSequence: sub.stopSequence,
              ),
            ),
          ),
        ));
      }
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

    final liveTrips = state.liveTrips;
    // Routes, or only live trips (an operator's tour without a route).
    final hasRoutes = catalog.routes.isNotEmpty || liveTrips.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [const BrandMark(), const SizedBox(width: 8), Text(l.appTitle)],
        ),
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
              if (cards.isEmpty && ended.isEmpty)
                _HintCard(title: l.homeNoStopsTitle, body: l.homeNoStopsBody),
              ...cards,
              for (final sub in ended)
                _EndedLiveFollow(
                  key: ValueKey('ended-${sub.tripInstanceId}:${sub.stopSequence}'),
                  subscription: sub,
                ),
              if (liveTrips.isNotEmpty) ...[
                _Header(l.liveTripsHeader),
                for (final t in liveTrips) _LiveTripTile(trip: t, now: now),
              ],
              if (catalog.routes.isNotEmpty) ...[
                _Header(l.routesHeader),
                ..._routeTiles(context, catalog),
              ],
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
      tiles.add(OperatorCover(key: ValueKey('cover-${op.id}'), operator: op));
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

/// A followed stop of a live trip that is no longer shown (past
/// `visible_until`, or no longer visible): say so and let the rider unfollow.
class _EndedLiveFollow extends StatefulWidget {
  const _EndedLiveFollow({super.key, required this.subscription});
  final Subscription subscription;

  @override
  State<_EndedLiveFollow> createState() => _EndedLiveFollowState();
}

class _EndedLiveFollowState extends State<_EndedLiveFollow> {
  bool _busy = false;

  Future<void> _unfollow() async {
    setState(() => _busy = true);
    try {
      await AppScope.read(context).unfollow(widget.subscription);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final op = state.catalog.operator(widget.subscription.operatorId);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_busy_outlined),
        title: Text(l.liveTripEnded),
        subtitle: op == null ? null : Text(op.name.resolve(context.lang)),
        trailing: TextButton(
          onPressed: _busy ? null : _unfollow,
          child: Text(l.unfollow),
        ),
      ),
    );
  }
}

/// A live trip on home: title, operator, and the next stop with its time.
class _LiveTripTile extends StatelessWidget {
  const _LiveTripTile({required this.trip, required this.now});
  final TripInstance trip;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final op = state.catalog.operator(trip.operatorId ?? '');
    final route = trip.routeId == null ? null : state.catalog.route(trip.routeId!);
    final next = nextLiveStop(trip, now);
    final first = trip.plannedStops.isEmpty ? null : liveVisitAt(trip, trip.plannedStops.first.sequence, now);
    final status = next == null
        ? (first == null ? '' : phaseText(context, first.tripPhase))
        : '${context.l10n.liveTripNextStop(next.stop.stopName.resolve(context.lang))} · '
              '${visitText(context, next.visit, op, now)}';
    return ListTile(
      key: ValueKey('live-${trip.id}'),
      leading: OperatorAvatar(operator: op),
      title: Text(liveTripTitle(context, trip)),
      subtitle: Text([op?.name.resolve(context.lang) ?? '', status].where((t) => t.isNotEmpty).join('\n')),
      isThreeLine: status.isNotEmpty,
      trailing: route == null ? null : RouteBadge(route: route),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveTripScreen(tripInstanceId: trip.id)),
      ),
    );
  }
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
          const BrandMark(size: 64),
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

/// One followed stop: operator, route (or live trip), stop and the next
/// arrival.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.subscription,
    required this.operatorId,
    required this.route,
    required this.stopName,
    required this.next,
    required this.now,
    required this.onOpen,
    this.tripTitle,
  });

  final Subscription subscription;
  final String operatorId;
  final BusRoute? route;
  final String stopName;

  /// For a stop of a live trip: the trip's title.
  final String? tripTitle;
  final NextArrival next;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final op = state.catalog.operator(operatorId);
    final visit = next.next;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Cancelled in the error colour; delays in the brand's delayed colour, never red.
    final statusColor = switch (visit?.kind) {
      VisitKind.cancelled => scheme.error,
      VisitKind.delayed => context.brand.delayedText,
      _ => null,
    };
    final offRoute = visit?.instance?.offRouteSince;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
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
                  if (route != null) RouteBadge(route: route!),
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
                          patternId: subscription.patternId,
                          tripInstanceId: subscription.tripInstanceId,
                          stopSequence: subscription.stopSequence,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(stopName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    visitIcon(visit?.kind),
                    color: statusColor ?? scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visitText(context, visit, op, now),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: statusColor,
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
                    ?tripTitle,
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
                  style: theme.textTheme.bodySmall?.copyWith(color: context.brand.unknownText),
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
