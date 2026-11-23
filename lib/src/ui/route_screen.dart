import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../data/arrivals.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'alert_settings_screen.dart';
import 'home_screen.dart';
import 'route_map.dart';
import 'theme.dart';
import 'widgets.dart';

/// A route: its stops in order with state and ETA for one trip today, and the
/// map where the audience may see it.
class RouteScreen extends StatefulWidget {
  const RouteScreen({
    super.key,
    required this.routeId,
    this.patternId,
    this.highlightSequence,
  });

  final String routeId;
  final String? patternId;
  final int? highlightSequence;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> with Polling {
  String? _patternId;

  /// The chosen trip of the day (trip id or, for live trips, instance id).
  String? _tripKey;

  @override
  void initState() {
    super.initState();
    _patternId = widget.patternId;
  }

  static String? _keyOf(Visit v) => v.trip?.id ?? v.instance?.id;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final catalog = state.catalog;
    final route = catalog.route(widget.routeId);
    if (route == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.routeGone)));
    }
    final op = catalog.operator(route.operatorId);
    final patterns = route.patterns;
    final pattern = patterns.firstWhere(
      (p) => p.id == _patternId,
      orElse: () => patterns.first,
    );
    final now = state.clock();
    final stops = pattern.stops;

    // Trips of the day, from the visits at the first stop.
    final tripVisits = stops.isEmpty
        ? const <Visit>[]
        : visitsAt(
            catalog: catalog,
            route: route,
            pattern: pattern,
            sequence: stops.first.sequence,
            instances: state.instances,
            now: now,
          );
    final current = currentVisitOfPattern(
      catalog: catalog,
      route: route,
      pattern: pattern,
      instances: state.instances,
      now: now,
    );
    final selectedKey = _tripKey ?? (current == null ? null : _keyOf(current));

    Visit? visitFor(int sequence) {
      for (final v in visitsAt(
        catalog: catalog,
        route: route,
        pattern: pattern,
        sequence: sequence,
        instances: state.instances,
        now: now,
      )) {
        if (_keyOf(v) == selectedKey) return v;
      }
      return null;
    }

    final rows = [for (final s in stops) (stop: s, visit: visitFor(s.sequence))];
    final nextIndex = rows.indexWhere(
      (r) =>
          r.visit != null &&
          r.visit!.kind != VisitKind.passed &&
          r.visit!.kind != VisitKind.atStop,
    );
    final selectedVisit = rows.isEmpty ? null : rows.first.visit;
    final instance = selectedVisit?.instance;
    final showMap = catalog.canSeeMap(route) && AppConfig.mapStyleUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            RouteBadge(route: route),
            const SizedBox(width: 8),
            Expanded(
              child: Text(route.name.resolve(context.lang), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          children: [
            UpdatedLine(fetchedAt: state.fetchedAt, offline: state.offline),
            if (showMap)
              SizedBox(
                height: 240,
                child: RouteMap(
                  key: ValueKey(pattern.id),
                  route: route,
                  pattern: pattern,
                  tripInstanceId: instance?.status == TripStatus.active ? instance?.id : null,
                ),
              ),
            if (patterns.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<String>(
                  segments: [
                    for (final p in patterns)
                      ButtonSegment(value: p.id, label: Text(p.name)),
                  ],
                  selected: {pattern.id},
                  onSelectionChanged: (s) => setState(() {
                    _patternId = s.first;
                    _tripKey = null;
                  }),
                ),
              ),
            if (tripVisits.isEmpty)
              ListTile(
                leading: const Icon(Icons.event_busy),
                title: Text(l.arrivalNoBusToday),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final v in tripVisits)
                      ChoiceChip(
                        label: Text(
                          v.scheduled == null
                              ? (v.instance?.title.resolve(context.lang) ?? l.liveTrip)
                              : formatTime(v.scheduled!, op),
                        ),
                        avatar: v.kind == VisitKind.cancelled
                            ? const Icon(Icons.cancel_outlined, size: 18)
                            : null,
                        selected: _keyOf(v) == selectedKey,
                        onSelected: (_) => setState(() => _tripKey = _keyOf(v)),
                      ),
                  ],
                ),
              ),
            if (selectedVisit != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  phaseText(context, selectedVisit.tripPhase),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            if (instance?.offRouteSince != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  l.positionUnknownSince(formatTime(instance!.offRouteSince!, op)),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              _StopRow(
                key: ValueKey('stop-${rows[i].stop.sequence}'),
                route: route,
                pattern: pattern,
                stop: rows[i].stop,
                visit: rows[i].visit,
                isNext: i == nextIndex,
                isFirst: i == 0,
                isLast: i == rows.length - 1,
                highlighted: rows[i].stop.sequence == widget.highlightSequence,
                followed: catalog.subscriptionFor(pattern.id, rows[i].stop.sequence) != null,
                now: now,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.route,
    required this.pattern,
    required this.stop,
    required this.visit,
    required this.isNext,
    required this.isFirst,
    required this.isLast,
    required this.highlighted,
    required this.followed,
    required this.now,
  });

  final BusRoute route;
  final TripPattern pattern;
  final PatternStop stop;
  final Visit? visit;
  final bool isNext;
  final bool isFirst;
  final bool isLast;
  final bool highlighted;
  final bool followed;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final op = AppScope.of(context).catalog.operator(route.operatorId);
    final kind = visit?.kind;
    final passed = kind == VisitKind.passed;
    final lineColor = routeColors(route.color, route.textColor, scheme).background;

    final String stateLabel = switch (kind) {
      VisitKind.passed => l.stopPassed,
      VisitKind.atStop => l.stopAtStop,
      VisitKind.cancelled => l.phaseCancelled,
      null => '',
      _ => isNext ? l.stopNext : l.stopUpcoming,
    };
    final time = visit?.time ?? visit?.scheduled;
    final timeText = time == null ? '' : formatTime(time, op);
    final delayed = kind == VisitKind.delayed;

    return Material(
      color: highlighted ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlertSettingsScreen(
              patternId: pattern.id,
              stopSequence: stop.sequence,
            ),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 16),
              SizedBox(
                width: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Expanded(child: Container(width: 4, color: isFirst ? Colors.transparent : lineColor)),
                        Expanded(child: Container(width: 4, color: isLast ? Colors.transparent : lineColor)),
                      ],
                    ),
                    Container(
                      width: isNext || kind == VisitKind.atStop ? 18 : 12,
                      height: isNext || kind == VisitKind.atStop ? 18 : 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: passed ? scheme.surfaceContainerHighest : scheme.surface,
                        border: Border.all(color: lineColor, width: 3),
                      ),
                      child: kind == VisitKind.atStop
                          ? Icon(Icons.directions_bus, size: 10, color: lineColor)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.stopName.resolve(context.lang),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: passed ? scheme.onSurfaceVariant : null,
                          fontWeight: isNext ? FontWeight.bold : null,
                        ),
                      ),
                      if (stateLabel.isNotEmpty)
                        Text(
                          delayed
                              ? '$stateLabel · ${l.delayedBy(visit!.delay.inMinutes)}'
                              : stateLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: delayed || kind == VisitKind.cancelled
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  timeText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: passed ? scheme.onSurfaceVariant : (delayed ? scheme.error : null),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: followed ? l.alertSettings : l.followStop,
                icon: Icon(followed ? Icons.notifications_active : Icons.notifications_none),
                color: followed ? scheme.primary : null,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlertSettingsScreen(
                      patternId: pattern.id,
                      stopSequence: stop.sequence,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
