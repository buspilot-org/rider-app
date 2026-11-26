import 'dart:async';
import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../data/api.dart';
import '../data/ewkb.dart';
import '../data/models.dart';
import '../state/app_state.dart';
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
  });

  final BusRoute route;
  final TripPattern pattern;
  final String? tripInstanceId;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

// The map style is light in both app themes, so the light casing and stop
// marker are used.
const _casing = '#FFFFFF';
const _stopIcon = 'assets/markers/stop.png';
const _busIcon = 'assets/markers/bus-marker.png';

class _RouteMapState extends State<RouteMap> {
  MapLibreMapController? _controller;
  MapData? _data;
  LngLat? _vehicle;
  bool _styleLoaded = false;
  Timer? _timer;
  Symbol? _bus;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadVehicle());
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (old.tripInstanceId != widget.tripInstanceId) _loadVehicle();
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
      _vehicle = v?.position;
      await _draw();
    } catch (_) {
      // Keep the last position until the next poll.
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
    final c = _controller;
    final d = _data;
    if (c == null || d == null || !_styleLoaded) return;
    // The basemap is light in both themes, so the fallback is the light primary.
    final color = parseHexColor(widget.route.color) ?? BuspilotColors.light.primary;
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
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
        await c.addLine(LineOptions(geometry: geometry, lineColor: _casing, lineWidth: 10, lineJoin: 'round'));
        await c.addLine(LineOptions(geometry: geometry, lineColor: hex, lineWidth: 6, lineJoin: 'round'));
      }
      for (final p in d.stops.values) {
        await c.addSymbol(SymbolOptions(geometry: LatLng(p.lat, p.lng), iconImage: _stopIcon));
      }
      final all = [...d.line, ...d.stops.values];
      if (all.isNotEmpty) {
        await c.moveCamera(CameraUpdate.newLatLngBounds(_bounds(all), left: 32, right: 32, top: 32, bottom: 32));
      }
    }
    final v = _vehicle;
    if (v != null) {
      final opts = SymbolOptions(geometry: LatLng(v.lat, v.lng), iconImage: _busIcon, zIndex: 1);
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
    if (_failed) {
      return Center(child: Text(context.l10n.mapUnavailable));
    }
    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data!.isEmpty) {
      return Center(child: Text(context.l10n.mapUnavailable));
    }
    return MapLibreMap(
      styleString: AppConfig.mapStyleUrl,
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
        _draw(fit: true);
      },
    );
  }
}
