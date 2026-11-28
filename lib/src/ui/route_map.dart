import 'dart:async';
import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../data/api.dart';
import '../data/ewkb.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'bus_marker.dart';
import 'theme.dart';
import 'widgets.dart';

/// Route line, stops and (while a trip is active and on route) the bus.
/// Shown only at map level; the server returns no geometry otherwise.
/// The vehicle position is polled while the map is on screen.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.pattern,
    this.tripInstanceId,
    this.arriving = false,
    this.etaMinutes,
    this.delayMinutes,
  });

  final BusRoute route;
  final TripPattern pattern;
  final String? tripInstanceId;

  /// The bus is about to reach a stop the rider follows (まもなく到着).
  final bool arriving;

  /// Minutes until the bus reaches a stop the rider follows: the yamabuki
  /// "あと5分" label next to the bus (brand App board).
  final int? etaMinutes;

  /// Minutes the bus is late: the "+5分" badge on the bus (brand Icons board).
  final int? delayMinutes;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A bus position older than this is shown as "no signal" (位置不明): grey
/// tile, no dot. The same default as the admin console.
/// Measured with the phone's clock: a clock more than this fast shows every
/// bus as no signal (the admin console has the same limit with the browser's).
const staleVehicleAfter = Duration(minutes: 2);

/// The bus marker for [vehicle] at [now]: no signal when the position is
/// stale, else arriving (yamabuki halo) or the plain bus.
String busMarkerFor(VehiclePosition vehicle, {required DateTime now, required bool arriving}) {
  final at = vehicle.recordedAt;
  if (at != null && now.difference(at) > staleVehicleAfter) return 'assets/markers/bus-no-signal.png';
  return arriving ? 'assets/markers/bus-arriving.png' : 'assets/markers/bus-marker.png';
}

class _RouteMapState extends State<RouteMap> {
  MapLibreMapController? _controller;
  MapData? _data;
  VehiclePosition? _vehicle;
  bool _styleLoaded = false;
  Timer? _timer;
  Symbol? _bus;
  bool _failed = false;

  /// Painted bus markers already added to the current style.
  final Set<String> _images = {};

  /// The map style is dark (only with a dark style URL); else the light
  /// casing, stop marker and colours are used in both app themes.
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadVehicle());
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (old.tripInstanceId != widget.tripInstanceId) {
      _loadVehicle();
    } else if (old.arriving != widget.arriving ||
        old.etaMinutes != widget.etaMinutes ||
        old.delayMinutes != widget.delayMinutes) {
      _draw();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Route line and stops, once.
  Future<void> _load() async {
    try {
      final data = await AppScope.read(context).api.fetchMapData(
        shapeId: widget.pattern.shapeId,
        stopIds: [for (final s in widget.pattern.stops) s.stopId],
      );
      if (!mounted) return;
      setState(() => _data = data);
      await _draw(fit: true);
      await _loadVehicle();
    } catch (_) {
      // Offline or not allowed: no map.
      if (mounted && _data == null) setState(() => _failed = true);
    }
  }

  /// The bus, polled while the map is on screen (LiveSource).
  Future<void> _loadVehicle() async {
    final id = widget.tripInstanceId;
    try {
      final v = id == null ? null : await AppScope.read(context).live.fetchVehicle(id);
      if (!mounted) return;
      _vehicle = v;
      await _draw();
    } catch (_) {
      // Keep the last position until the next poll, but redraw: it may have
      // become stale (no signal).
      if (mounted) await _draw();
    }
  }

  // Draws one at a time: a poll during a refit must not add a second bus.
  Future<void> _drawing = Future.value();

  Future<void> _draw({bool fit = false}) {
    final next = _drawing.then((_) => _drawNow(fit: fit)).catchError((_) {});
    _drawing = next;
    return next;
  }

  Future<void> _drawNow({bool fit = false}) async {
    if (!mounted) return;
    final c = _controller;
    final d = _data;
    if (c == null || d == null || !_styleLoaded) return;
    final now = AppScope.read(context).clock();
    final l = context.l10n;
    // Colours of the map, not of the app: the light basemap keeps the light
    // palette in the dark theme. Route: primary, 2 px casing in white (light)
    // or the background colour (dark) (brand README, Map markers).
    final bp = _dark ? BuspilotColors.dark : BuspilotColors.light;
    final hex = _hex(parseHexColor(widget.route.color) ?? bp.primary);
    final casing = _dark ? _hex(bp.background) : '#FFFFFF';
    final stopIcon = _dark ? 'assets/markers/stop-dark.png' : 'assets/markers/stop.png';
    if (fit) {
      await c.clearLines();
      await c.clearSymbols();
      _bus = null;
      // Markers from the brand (assets/markers/); the map draws no shadow.
      await c.setSymbolIconAllowOverlap(true);
      await c.setSymbolIconIgnorePlacement(true);
      if (d.line.length >= 2) {
        final geometry = [for (final p in d.line) LatLng(p.lat, p.lng)];
        // Route: 6 px in the route colour with a 2 px casing.
        await c.addLine(LineOptions(geometry: geometry, lineColor: casing, lineWidth: 10, lineJoin: 'round'));
        await c.addLine(LineOptions(geometry: geometry, lineColor: hex, lineWidth: 6, lineJoin: 'round'));
      }
      for (final p in d.stops.values) {
        await c.addSymbol(SymbolOptions(geometry: LatLng(p.lat, p.lng), iconImage: stopIcon));
      }
      final all = [...d.line, ...d.stops.values];
      if (all.isNotEmpty) {
        await c.moveCamera(CameraUpdate.newLatLngBounds(_bounds(all), left: 32, right: 32, top: 32, bottom: 32));
      }
    }
    final v = _vehicle;
    if (v != null) {
      final base = busMarkerFor(v, now: now, arriving: widget.arriving);
      final icon = await _busIcon(c, base, bp, l);
      if (!mounted) return;
      final opts = SymbolOptions(geometry: LatLng(v.position.lat, v.position.lng), iconImage: icon, zIndex: 1);
      if (_bus == null) {
        _bus = await c.addSymbol(opts);
      } else {
        await c.updateSymbol(_bus!, opts);
      }
    } else if (_bus != null) {
      await c.removeSymbol(_bus!);
      _bus = null;
    }
  }

  /// [base], or [base] with the ETA label and delay badge painted on. No
  /// labels without a signal: the position and the times are not known.
  Future<String> _busIcon(MapLibreMapController c, String base, BuspilotColors bp, AppLocalizations l) async {
    if (base == 'assets/markers/bus-no-signal.png') return base;
    final eta = widget.etaMinutes;
    final delay = widget.delayMinutes;
    final etaText = eta != null && eta > 0 ? l.etaInMinutes(eta) : null;
    final delayText = delay != null && delay > 0 ? l.mapDelayBadge(delay) : null;
    if (etaText == null && delayText == null) return base;
    final name = 'bus|$base|$_dark|${etaText ?? ''}|${delayText ?? ''}';
    if (_images.add(name)) {
      try {
        final bytes = await paintBusMarker(markerAsset: base, colors: bp, eta: etaText, delay: delayText);
        await c.addImage(name, bytes, false, busMarkerPixelRatio);
      } catch (_) {
        _images.remove(name);
        return base;
      }
    }
    return name;
  }

  LatLngBounds _bounds(List<LngLat> points) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_failed) {
      // A next step: try again (brand voice).
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.mapFailed, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _load();
                },
                child: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l.mapUnavailable, textAlign: TextAlign.center),
        ),
      );
    }
    final state = AppScope.of(context);
    final brightness = Theme.of(context).brightness;
    if (state.mapIsDark(brightness) != _dark) {
      // The style changes: its lines, symbols and images are redrawn when it
      // has loaded.
      _dark = state.mapIsDark(brightness);
      _styleLoaded = false;
    }
    return MapLibreMap(
      styleString: state.mapStyleFor(brightness),
      initialCameraPosition: CameraPosition(
        target: LatLng(_data!.line.firstOrNull?.lat ?? 35.68, _data!.line.firstOrNull?.lng ?? 139.76),
        zoom: 13,
      ),
      myLocationEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      onMapCreated: (c) => _controller = c,
      onStyleLoadedCallback: () {
        _styleLoaded = true;
        _images.clear();
        _draw(fit: true);
      },
    );
  }
}
