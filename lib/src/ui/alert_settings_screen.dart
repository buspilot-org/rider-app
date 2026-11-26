import 'package:material_ui/material_ui.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/arrivals.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'stop_mini_map.dart';
import 'widgets.dart';

/// Follow a stop and set its alerts (`subscription`): a stop of a pattern
/// ([patternId]) or a planned stop of a live trip ([tripInstanceId]).
class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({
    super.key,
    this.patternId,
    this.tripInstanceId,
    required this.stopSequence,
  }) : assert((patternId == null) != (tripInstanceId == null));

  final String? patternId;
  final String? tripInstanceId;
  final int stopSequence;

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

enum _Pause { off, today, until }

/// The choices offered: minutes or stops before the bus arrives.
const _minuteChoices = [3, 5, 10];
const _stopChoices = [1, 2];

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  Subscription? _existing;
  late Subscription _draft;
  _Pause _pause = _Pause.off;
  DateTime? _pauseUntil;
  bool _busy = false;
  bool _initialised = false;

  /// The followed stop, resolved from the catalog or the live trips.
  ({
    String operatorId,
    BusRoute? route,
    String subtitle,
    String stopName,
    String? stopId,
  })?
  _target(AppState state) {
    final lang = context.lang;
    final patternId = widget.patternId;
    if (patternId != null) {
      final found = state.catalog.pattern(patternId);
      if (found == null) return null;
      final stop = found.$2.stopAt(widget.stopSequence);
      return (
        operatorId: found.$1.operatorId,
        route: found.$1,
        subtitle: found.$2.name,
        stopName: stop?.stopName.resolve(lang) ?? '',
        stopId: stop?.stopId,
      );
    }
    final trip = state.liveTrip(widget.tripInstanceId!);
    if (trip == null || trip.operatorId == null) return null;
    final stop = trip.plannedStopAt(widget.stopSequence);
    final title = trip.title.resolve(lang);
    return (
      operatorId: trip.operatorId!,
      route: trip.routeId == null ? null : state.catalog.route(trip.routeId!),
      subtitle: title.isEmpty ? context.l10n.liveTrip : title,
      stopName: stop?.stopName.resolve(lang) ?? '',
      stopId: stop?.stopId,
    );
  }

  Subscription? _find(AppState state) => widget.patternId != null
      ? state.catalog.subscriptionFor(widget.patternId!, widget.stopSequence)
      : state.catalog.liveSubscriptionFor(
          widget.tripInstanceId!,
          widget.stopSequence,
        );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final state = AppScope.read(context);
    _existing = _find(state);
    _draft =
        _existing ??
        Subscription(
          operatorId: _target(state)?.operatorId ?? '',
          patternId: widget.patternId,
          tripInstanceId: widget.tripInstanceId,
          stopSequence: widget.stopSequence,
        );
    final muted = _draft.mutedUntil;
    if (muted != null && muted.isAfter(state.clock())) {
      _pause = _Pause.until;
      _pauseUntil = muted;
    }
  }

  Operator? get _operator {
    final state = AppScope.read(context);
    return state.catalog.operator(_target(state)?.operatorId ?? '');
  }

  tz.Location get _loc => locationOf(_operator);

  /// End of the service day of [day] in the operator's time zone.
  DateTime _endOf(DateTime day) => tz.TZDateTime(
    _loc,
    day.year,
    day.month,
    day.day,
  ).add(const Duration(days: 1));

  Subscription _withPause() {
    final now = AppScope.read(context).clock();
    return switch (_pause) {
      _Pause.off => _draft.copyWith(clearMute: true),
      _Pause.today => _draft.copyWith(
        mutedUntil: _endOf(serviceDay(_loc, now)),
      ),
      _Pause.until =>
        _pauseUntil == null
            ? _draft.copyWith(clearMute: true)
            : _draft.copyWith(mutedUntil: _pauseUntil),
    };
  }

  Future<void> _pickDate() async {
    final now = AppScope.read(context).clock();
    final today = serviceDay(_loc, now);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initialDate: DateTime(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _pause = _Pause.until;
        // Paused through the end of the chosen day.
        _pauseUntil = _endOf(picked);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final state = AppScope.read(context);
    final l = context.l10n;
    try {
      final isNew = await state.saveSubscription(_withPause());
      if (!mounted) return;
      // No push for live trips yet (the engine skips those subscriptions).
      if (isNew && state.shouldOfferPush && widget.tripInstanceId == null) {
        // Say why before the system asks (concept: rider-app.md).
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.notifications_active_outlined),
            title: Text(l.pushAskTitle),
            content: Text(l.pushAskBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l.notNow),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l.continueButton),
              ),
            ],
          ),
        );
        if (ok == true) await state.enablePush();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? l.followSaved : l.alertSaved)),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _unfollow() async {
    setState(() => _busy = true);
    try {
      await AppScope.read(context).unfollow(_existing!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = AppScope.of(context);
    final target = _target(state);
    final stopName = target?.stopName ?? '';
    final theme = Theme.of(context);
    final choices = _draft.trigger == AlertTrigger.minutes
        ? _minuteChoices
        : _stopChoices;
    final until = _pauseUntil;

    return Scaffold(
      appBar: AppBar(title: Text(stopName)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (target == null)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                widget.patternId != null ? l.routeGone : l.liveTripGone,
              ),
            )
          else if (target.route != null)
            ListTile(
              leading: RouteBadge(route: target.route!),
              title: Text(target.route!.name.resolve(context.lang)),
              subtitle: Text(target.subtitle),
            )
          else
            ListTile(
              leading: const Icon(Icons.directions_bus_outlined),
              title: Text(target.subtitle),
            ),
          // Only this stop, where the server returns its location; else a
          // short note why there is no map.
          if (target?.stopId != null)
            StopMiniMap(stopId: target!.stopId!, followed: _existing != null),
          const Divider(),
          // The engine does not send alerts for live trips yet: follow for
          // home only, without alert settings that would promise them.
          if (widget.tripInstanceId != null)
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l.liveTripNoAlerts),
            ),
          if (widget.tripInstanceId == null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.alertWhen, style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<AlertTrigger>(
                segments: [
                  ButtonSegment(
                    value: AlertTrigger.minutes,
                    label: Text(l.alertByMinutes),
                  ),
                  ButtonSegment(
                    value: AlertTrigger.stops,
                    label: Text(l.alertByStops),
                  ),
                ],
                selected: {_draft.trigger},
                onSelectionChanged: (s) => setState(() {
                  final t = s.first;
                  _draft = _draft.copyWith(
                    trigger: t,
                    triggerValue: t == AlertTrigger.minutes ? 5 : 1,
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final v in choices)
                    ChoiceChip(
                      label: Text(
                        _draft.trigger == AlertTrigger.minutes
                            ? l.alertMinutesAway(v)
                            : l.alertStopsAway(v),
                      ),
                      selected: _draft.triggerValue == v,
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(triggerValue: v),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(l.alertNotifyPassed),
              value: _draft.notifyPassed,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(notifyPassed: v)),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l.alertPause, style: theme.textTheme.titleSmall),
            ),
            RadioGroup<_Pause>(
              groupValue: _pause,
              onChanged: (v) {
                if (v == _Pause.until) {
                  _pickDate();
                } else if (v != null) {
                  setState(() => _pause = v);
                }
              },
              child: Column(
                children: [
                  RadioListTile(
                    value: _Pause.off,
                    title: Text(l.alertPauseOff),
                  ),
                  RadioListTile(
                    value: _Pause.today,
                    title: Text(l.alertPauseToday),
                  ),
                  RadioListTile(
                    value: _Pause.until,
                    title: Text(
                      until == null
                          ? l.alertPauseUntilDate
                          : l.alertPausedThrough(
                              formatPausedThrough(
                                until,
                                _operator,
                                context.lang,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          if (!state.push.available && widget.tripInstanceId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.pushNotReady, style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton(
              key: const Key('save-alert'),
              onPressed: _busy || target == null ? null : _save,
              child: Text(_existing == null ? l.followStop : l.save),
            ),
          ),
          if (_existing != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: _busy ? null : _unfollow,
                child: Text(l.unfollow),
              ),
            ),
        ],
      ),
    );
  }
}
