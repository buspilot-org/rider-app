import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/arrivals.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Service days of the device's routes: a month view and the exceptions
/// (holidays, extra days).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  String? _routeId;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final state = AppScope.read(context);
    final now = state.clock();
    _month = DateTime.utc(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final catalog = state.catalog;
    final routes = catalog.routes;
    if (routes.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(l.calendarTitle)));
    }
    final route = routes.firstWhere((r) => r.id == _routeId, orElse: () => routes.first);
    final calendars = catalog.calendarsOfRoute(route);
    final op = catalog.operator(route.operatorId);
    final today = serviceDay(locationOf(op), state.clock());
    bool runs(DateTime d) => calendars.any((c) => c.runsOn(d));

    final exceptions = [
      for (final c in calendars) ...c.exceptions,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final upcoming = exceptions.where((e) => !e.end.isBefore(today)).toList();

    final lang = context.lang;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = _month;
    final daysInMonth = DateTime.utc(first.year, first.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday first
    final dayFmt = DateFormat.MMMEd(lang);

    return Scaffold(
      appBar: AppBar(title: Text(l.calendarTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (routes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownButton<String>(
                isExpanded: true,
                value: route.id,
                items: [
                  for (final r in routes)
                    DropdownMenuItem(value: r.id, child: Text(r.name.resolve(lang))),
                ],
                onChanged: (v) => setState(() => _routeId = v),
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: l.previousMonth,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime.utc(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(lang).format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l.nextMonth,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime.utc(_month.year, _month.month + 1)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
                for (var i = 0; i < 7; i++)
                  Center(
                    child: Text(
                      DateFormat.E(lang).format(DateTime.utc(2024, 1, 1 + i)),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                for (var d = 1; d <= daysInMonth; d++)
                  _Day(
                    day: DateTime.utc(first.year, first.month, d),
                    runs: runs(DateTime.utc(first.year, first.month, d)),
                    today: DateTime.utc(first.year, first.month, d) == today,
                    label: '${dayFmt.format(DateTime.utc(first.year, first.month, d))}: '
                        '${runs(DateTime.utc(first.year, first.month, d)) ? l.calendarServiceDay : l.calendarNoService}',
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _Legend(color: scheme.primaryContainer, text: l.calendarServiceDay),
                const SizedBox(width: 16),
                _Legend(color: scheme.surfaceContainerHighest, text: l.calendarNoService),
              ],
            ),
          ),
          if (calendars.any((c) => c.skipNationalHolidays))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.calendarHolidaysNote, style: theme.textTheme.bodySmall),
            ),
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l.calendarChanges,
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
              ),
            ),
          for (final e in upcoming)
            ListTile(
              leading: Icon(e.added ? Icons.event_available : Icons.event_busy),
              title: Text(
                e.start == e.end
                    ? dayFmt.format(e.start)
                    : '${dayFmt.format(e.start)} – ${dayFmt.format(e.end)}',
              ),
              subtitle: Text(
                [
                  e.added ? l.calendarExtraDay : l.calendarNoService,
                  if (e.reason != null && e.reason!.isNotEmpty) e.reason!,
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day, required this.runs, required this.today, required this.label});
  final DateTime day;
  final bool runs;
  final bool today;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: runs ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: today ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: runs ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            fontWeight: today ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 6),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
