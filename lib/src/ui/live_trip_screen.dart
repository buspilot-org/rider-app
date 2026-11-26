import 'package:material_ui/material_ui.dart';

import '../data/arrivals.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'alert_settings_screen.dart';
import 'home_screen.dart';
import 'route_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// A live trip with its own planned stops (an extra trip, a tour): the stops
/// in order with planned time, state and ETA. Riders follow a stop of this
/// one trip.
class LiveTripScreen extends StatefulWidget {
  const LiveTripScreen({super.key, required this.tripInstanceId, this.highlightSequence});

  final String tripInstanceId;
  final int? highlightSequence;

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> with Polling {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final trip = state.liveTrip(widget.tripInstanceId);
    if (trip == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.liveTripGone)));
    }
    final catalog = state.catalog;
    final op = catalog.operator(trip.operatorId ?? '');
    final route = trip.routeId == null ? null : catalog.route(trip.routeId!);
    final now = state.clock();
    final title = liveTripTitle(context, trip);
    final scheme = Theme.of(context).colorScheme;
    final lineColor = route == null
        ? scheme.primary
        : routeColors(route.color, route.textColor, scheme).background;
    final stops = trip.plannedStops;
    final rows = [for (final s in stops) (stop: s, visit: liveVisitAt(trip, s.sequence, now))];
    final next = nextLiveStop(trip, now);
    final phase = rows.isEmpty || rows.first.visit == null
        ? null
        : rows.first.visit!.tripPhase;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (route != null) ...[RouteBadge(route: route), const SizedBox(width: 8)],
            Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          children: [
            const UpdatedLine(),
            ListTile(
              leading: OperatorAvatar(operator: op),
              title: Text(op?.name.resolve(context.lang) ?? ''),
              subtitle: trip.visibleUntil == null
                  ? null
                  : Text(l.liveTripVisibleUntil(formatTime(trip.visibleUntil!, op))),
            ),
            if (phase != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Text(phaseText(context, phase), style: Theme.of(context).textTheme.titleSmall),
              ),
            if (trip.offRouteSince != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  l.positionUnknownSince(formatTime(trip.offRouteSince!, op)),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              StopTimelineRow(
                key: ValueKey('live-stop-${rows[i].stop.sequence}'),
                stopName: rows[i].stop.stopName.resolve(context.lang),
                operator: op,
                lineColor: lineColor,
                visit: rows[i].visit,
                isNext: next?.stop.sequence == rows[i].stop.sequence,
                isFirst: i == 0,
                isLast: i == rows.length - 1,
                highlighted: rows[i].stop.sequence == widget.highlightSequence,
                followed: catalog.liveSubscriptionFor(trip.id, rows[i].stop.sequence) != null,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlertSettingsScreen(
                      tripInstanceId: trip.id,
                      stopSequence: rows[i].stop.sequence,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The live trip's title in the reader's language, or "Extra trip".
String liveTripTitle(BuildContext context, TripInstance trip) {
  final t = trip.title.resolve(context.lang);
  return t.isEmpty ? context.l10n.liveTrip : t;
}
