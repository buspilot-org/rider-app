import 'package:material_ui/material_ui.dart';

import '../data/arrivals.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'alert_settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Within this many minutes, an approaching bus is "arriving soon".
const arrivingWithinMinutes = 3;

/// The status chip on a followed stop's card (brand status colours).
enum StopStatus { onTime, delayed, arriving, atStop, unknown, cancelled, notStarted }

/// Minutes until [time], rounded up.
int minutesUntil(DateTime time, DateTime now) => (time.difference(now).inSeconds / 60).ceil();

/// The chip for [visit], or null when there is nothing to say (no bus today,
/// or the bus has passed).
StopStatus? stopStatus(Visit? visit, DateTime now) {
  if (visit == null) return null;
  final time = visit.time ?? visit.scheduled;
  final soon = time != null && minutesUntil(time, now) <= arrivingWithinMinutes;
  final offRoute = visit.instance?.offRouteSince != null;
  return switch (visit.kind) {
    VisitKind.cancelled => StopStatus.cancelled,
    VisitKind.passed => null,
    VisitKind.atStop => StopStatus.atStop,
    // A trip on the timetable only (no live tracking): nothing to say yet.
    VisitKind.scheduled => visit.instance == null ? null : StopStatus.notStarted,
    VisitKind.onTheWay || VisitKind.delayed when offRoute => StopStatus.unknown,
    VisitKind.onTheWay || VisitKind.delayed when soon => StopStatus.arriving,
    VisitKind.delayed => StopStatus.delayed,
    VisitKind.onTheWay => StopStatus.onTime,
  };
}

/// Tint and text colour of [status] in the current theme.
({Color tint, Color text}) stopStatusColors(BuildContext context, StopStatus status) {
  final b = context.brand;
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    StopStatus.onTime => (tint: b.onTimeTint, text: b.onTimeText),
    StopStatus.delayed => (tint: b.delayedTint, text: b.delayedText),
    // Yamabuki only as a fill: the text uses arrivingText.
    StopStatus.arriving || StopStatus.atStop => (tint: b.arrivingTint, text: b.arrivingText),
    StopStatus.unknown => (tint: b.unknownTint, text: b.unknownText),
    StopStatus.cancelled => (tint: scheme.errorContainer, text: scheme.onErrorContainer),
    StopStatus.notStarted => (tint: b.primaryTint, text: b.onPrimaryTint),
  };
}

String stopStatusText(BuildContext context, StopStatus status) {
  final l = context.l10n;
  return switch (status) {
    StopStatus.onTime => l.statusOnTime,
    StopStatus.delayed => l.statusDelayed,
    StopStatus.arriving => l.statusArriving,
    StopStatus.atStop => l.statusAtStop,
    StopStatus.unknown => l.statusUnknown,
    StopStatus.cancelled => l.phaseCancelled,
    StopStatus.notStarted => l.statusNotStarted,
  };
}

/// One followed stop (brand App board): operator and status chip, a large
/// ETA, the arrival line, and the bus on its way to the stop.
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
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final status = stopStatus(visit, now);
    final colors = status == null ? null : stopStatusColors(context, status);
    final progress = visit == null ? null : tripProgress(visit, op, now);
    final offRoute = visit?.instance?.offRouteSince;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    OperatorAvatar(operator: op, radius: 12),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [op?.name.resolve(context.lang) ?? '', ?tripTitle].where((t) => t.isNotEmpty).join(' · '),
                        style: muted,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        // Long labels (German, large text) ellipsize instead of overflowing.
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: _StatusChip(
                          text: stopStatusText(context, status),
                          tint: colors!.tint,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Arrival(visit: visit, status: status, stopName: stopName, op: op, now: now),
              // No signal: no bus dot moving on a guess (like the no-signal map marker).
              if (progress != null && status != StopStatus.unknown) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TripProgressBar(value: progress),
                ),
              ],
              if (offRoute != null) ...[
                const SizedBox(height: 8),
                Text(
                  l.positionUnknownSince(formatTime(offRoute, op)),
                  style: theme.textTheme.bodySmall?.copyWith(color: context.brand.unknownText),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (visit != null && status == null && visit.kind != VisitKind.scheduled)
                          phaseText(context, visit.tripPhase),
                        if (visit?.trip case final trip?)
                          l.tripAt(
                            formatTime(
                              atOffset(
                                locationOf(op),
                                visit!.instance == null
                                    ? serviceDay(locationOf(op), now)
                                    : parseDate(visit.instance!.serviceDate),
                                trip.startTime,
                              ),
                              op,
                            ),
                          ),
                        if (subscription.isMuted(now))
                          l.alertPausedThrough(formatPausedThrough(subscription.mutedUntil!, op, context.lang)),
                      ].join(' · '),
                      style: muted,
                    ),
                  ),
                  if (route != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: RouteBadge(route: route!),
                    ),
                  IconButton(
                    tooltip: l.alertSettings,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      subscription.isMuted(now) ? Icons.notifications_paused_outlined : Icons.notifications_outlined,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// The large ETA ("あと 5分") and the arrival line, or what happened instead.
class _Arrival extends StatelessWidget {
  const _Arrival({
    required this.visit,
    required this.status,
    required this.stopName,
    required this.op,
    required this.now,
  });

  final Visit? visit;
  final StopStatus? status;
  final String stopName;
  final Operator? op;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final b = context.brand;
    final visit = this.visit;
    final time = visit?.time ?? visit?.scheduled;
    final lineStyle = theme.textTheme.bodyLarge;
    final etaColor = switch (status) {
      StopStatus.delayed => b.delayedText,
      StopStatus.arriving || StopStatus.atStop => b.arrivingText,
      StopStatus.unknown => b.unknownText,
      _ => b.primary,
    };
    // Brand `eta` style: 44 sp, weight 800, line height 1.0.
    final eta = theme.textTheme.displaySmall?.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      height: 1.0,
      color: etaColor,
    );
    final etaUnit = theme.textTheme.titleLarge?.copyWith(color: etaColor);

    final upcoming =
        visit != null &&
        time != null &&
        (visit.kind == VisitKind.scheduled || visit.kind == VisitKind.onTheWay || visit.kind == VisitKind.delayed);
    if (!upcoming) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            visit?.kind == VisitKind.atStop ? l.arrivalAtStop : visitText(context, visit, op, now),
            style: theme.textTheme.titleLarge?.copyWith(color: visit?.kind == VisitKind.atStop ? etaColor : null),
          ),
          const SizedBox(height: 2),
          Text(stopName, style: lineStyle),
        ],
      );
    }

    final t = formatTime(time, op);
    final minutes = minutesUntil(time, now);
    final Widget big;
    if (minutes <= 0 && visit.kind == VisitKind.scheduled) {
      // No live data: the timetable time, not "arriving now".
      big = Text(t, style: eta);
    } else if (minutes <= 0) {
      big = Text(l.etaDue, style: theme.textTheme.titleLarge?.copyWith(color: etaColor));
    } else if (visit.kind == VisitKind.scheduled && minutes > 60) {
      big = Text(t, style: eta);
    } else {
      big = _EtaMinutes(text: l.etaInMinutes(minutes), minutes: minutes, numberStyle: eta, unitStyle: etaUnit);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        big,
        const SizedBox(height: 6),
        Text(
          visit.kind == VisitKind.delayed
              ? l.etaArrivesAround(stopName, t, visit.delay.inMinutes)
              : l.etaArrivesAt(stopName, t),
          style: lineStyle,
        ),
      ],
    );
  }
}

/// "あと 5分" / "in 5 min" with the number in the large `eta` style.
class _EtaMinutes extends StatelessWidget {
  const _EtaMinutes({required this.text, required this.minutes, required this.numberStyle, required this.unitStyle});

  final String text;
  final int minutes;
  final TextStyle? numberStyle;
  final TextStyle? unitStyle;

  @override
  Widget build(BuildContext context) {
    final n = '$minutes';
    final prefixStyle = unitStyle?.copyWith(color: Theme.of(context).colorScheme.onSurface);
    final at = text.indexOf(n);
    final spans = at < 0
        ? [TextSpan(text: text, style: unitStyle)]
        : [
            // "あと" / "in" in the text colour, as on the App board; "5分" in the ETA colour.
            if (at > 0) TextSpan(text: text.substring(0, at), style: prefixStyle),
            TextSpan(text: n, style: numberStyle),
            if (at + n.length < text.length) TextSpan(text: text.substring(at + n.length)),
          ];
    return Text.rich(
      TextSpan(style: unitStyle, children: spans),
      textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.tint, required this.color});

  final String text;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('stop-status'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    ),
  );
}

/// The trip so far: a track in the brand tint, the part driven in `primary`,
/// and the bus as a yamabuki dot (fill only). The status chip carries the
/// status colour, so the bar stays calm.
class TripProgressBar extends StatelessWidget {
  const TripProgressBar({super.key, required this.value});

  final double value;

  static const _dot = 14.0;
  static const _track = 6.0;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    // Decorative: the ETA text above says the same for screen readers.
    return ExcludeSemantics(
      child: SizedBox(
        height: _dot,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final x = (w - _dot) * value;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: _track,
                  decoration: BoxDecoration(color: b.primaryTint, borderRadius: BorderRadius.circular(_track / 2)),
                ),
                Container(
                  width: x + _dot / 2,
                  height: _track,
                  decoration: BoxDecoration(color: b.primary, borderRadius: BorderRadius.circular(_track / 2)),
                ),
                Positioned(
                  left: x,
                  child: Container(
                    key: const ValueKey('bus-dot'),
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(
                      color: b.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: b.surface, width: 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
