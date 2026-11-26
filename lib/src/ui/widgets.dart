import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
import '../data/api.dart';
import '../data/arrivals.dart';
import '../data/branding.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'theme.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get lang => Localizations.localeOf(this).languageCode;
}

/// "07:42" in the operator's time zone.
String formatTime(DateTime t, Operator? op) {
  final local = tz.TZDateTime.from(t, locationOf(op));
  return DateFormat.Hm().format(local);
}

/// "07:42" on the phone's clock (for "as of" times).
String formatLocalTime(DateTime t) => DateFormat.Hm().format(t.toLocal());

/// "Fri, Dec 5": the last day of a pause ending at [mutedUntil] (the
/// midnight after that day).
String formatPausedThrough(DateTime mutedUntil, Operator? op, String lang) =>
    DateFormat.MMMEd(lang).format(
      tz.TZDateTime.from(mutedUntil, locationOf(op)).subtract(const Duration(minutes: 1)),
    );

/// Operator logo, or its initial on the brand colour.
class OperatorAvatar extends StatelessWidget {
  const OperatorAvatar({super.key, required this.operator, this.radius = 18});

  final Operator? operator;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = routeColors(operator?.colorHex, null, scheme);
    final name = operator?.name.resolve(context.lang) ?? '?';
    final logo = operator == null
        ? null
        : brandingImageUrl(
            operator!.logoUrl,
            backendUrl: AppConfig.supabaseUrl,
            operatorId: operator!.id,
          );
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.background,
      foregroundColor: colors.foreground,
      foregroundImage: logo == null ? null : NetworkImage(logo),
      child: Text(name.isEmpty ? '?' : name.characters.first),
    );
  }
}

/// The operator's cover image (`branding.cover_url`) with its name, above
/// its routes. Nothing when there is no cover or it is not on the Buspilot
/// backend.
class OperatorCover extends StatelessWidget {
  const OperatorCover({super.key, required this.operator});

  final Operator operator;

  @override
  Widget build(BuildContext context) {
    final url = brandingImageUrl(
      operator.coverUrl,
      backendUrl: AppConfig.supabaseUrl,
      operatorId: operator.id,
    );
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 3,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            semanticLabel: operator.name.resolve(context.lang),
            // Offline or not found: no cover rather than a broken image.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Short route name on the route colour.
class RouteBadge extends StatelessWidget {
  const RouteBadge({super.key, required this.route});

  final BusRoute route;

  @override
  Widget build(BuildContext context) {
    final colors = routeColors(route.color, route.textColor, Theme.of(context).colorScheme);
    final label = route.shortName ?? route.name.resolve(context.lang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.foreground),
      ),
    );
  }
}

/// The text for a visit, e.g. "07:42 · in 4 min", "Passed 07:38".
String visitText(BuildContext context, Visit? visit, Operator? op, DateTime now) {
  final l = context.l10n;
  if (visit == null) return l.arrivalNoBusToday;
  final time = visit.time ?? visit.scheduled;
  final t = time == null ? '–' : formatTime(time, op);
  switch (visit.kind) {
    case VisitKind.cancelled:
      return l.arrivalCancelled(t);
    case VisitKind.passed:
      return l.arrivalPassed(t);
    case VisitKind.atStop:
      return l.arrivalAtStop;
    case VisitKind.delayed:
      return l.arrivalDelayed(visit.delay.inMinutes, t);
    case VisitKind.onTheWay:
    case VisitKind.scheduled:
      if (time == null) return t;
      final minutes = (time.difference(now).inSeconds / 60).ceil();
      if (visit.kind == VisitKind.scheduled && minutes > 60) {
        return l.arrivalScheduled(t);
      }
      if (minutes <= 0) return l.arrivalDue(t);
      return l.arrivalInMinutes(minutes, t);
  }
}

IconData visitIcon(VisitKind? kind) => switch (kind) {
  VisitKind.onTheWay => Icons.directions_bus,
  VisitKind.delayed => Icons.schedule,
  VisitKind.atStop => Icons.place,
  VisitKind.passed => Icons.check_circle_outline,
  VisitKind.cancelled => Icons.cancel_outlined,
  VisitKind.scheduled => Icons.access_time,
  null => Icons.event_busy,
};

String phaseText(BuildContext context, TripPhase phase) => switch (phase) {
  TripPhase.notStarted => context.l10n.phaseNotStarted,
  TripPhase.onTheWay => context.l10n.phaseOnTheWay,
  TripPhase.finished => context.l10n.phaseFinished,
  TripPhase.cancelled => context.l10n.phaseCancelled,
};

/// "As of 07:31", or why the data is older: offline or not updated.
class UpdatedLine extends StatelessWidget {
  const UpdatedLine({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final fetchedAt = state.fetchedAt;
    if (fetchedAt == null) return const SizedBox.shrink();
    final t = formatLocalTime(fetchedAt);
    final stale = state.offline || state.serverError;
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final color = stale ? scheme.error : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(stale ? Icons.cloud_off : Icons.update, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              state.offline
                  ? l.offlineAsOf(t)
                  : state.serverError
                  ? l.notUpdatedAsOf(t)
                  : l.asOf(t),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows an error from an API call as a snack bar.
void showError(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = context.l10n;
  final text = error is OfflineException
      ? l.offlineError
      : l.genericError;
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
