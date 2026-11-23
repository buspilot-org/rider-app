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

class _RouteMapState extends State<RouteMap> {
  MapLibreMapController? _controller;
  MapData? _data;
  bool _styleLoaded = false;
  Timer? _timer;
  Circle? _bus;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (old.tripInstanceId != widget.tripInstanceId) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.read(context).api.fetchMapData(
        shapeId: widget.pattern.shapeId,
        stopIds: [for (final s in widget.pattern.stops) s.stopId],
        tripInstanceId: widget.tripInstanceId,
      );
      if (!mounted) return;
      final first = _data == null;
      _data = data;
      if (first) setState(() {});
      await _draw(fit: first);
    } on OfflineException {
      if (mounted && _data == null) setState(() => _failed = true);
    }
  }

  Future<void> _draw({bool fit = false}) async {
    final c = _controller;
    final d = _data;
    if (c == null || d == null || !_styleLoaded) return;
    final color = parseHexColor(widget.route.color) ?? Theme.of(context).colorScheme.primary;
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    if (fit) {
      await c.clearLines();
      await c.clearCircles();
      _bus = null;
      if (d.line.length >= 2) {
        await c.addLine(LineOptions(
          geometry: [for (final p in d.line) LatLng(p.lat, p.lng)],
          lineColor: hex,
          lineWidth: 4,
        ));
      }
      for (final p in d.stops.values) {
        await c.addCircle(CircleOptions(
          geometry: LatLng(p.lat, p.lng),
          circleRadius: 6,
          circleColor: '#FFFFFF',
          circleStrokeColor: hex,
          circleStrokeWidth: 3,
        ));
      }
      final all = [...d.line, ...d.stops.values];
      if (all.isNotEmpty) {
        await c.moveCamera(CameraUpdate.newLatLngBounds(_bounds(all), left: 32, right: 32, top: 32, bottom: 32));
      }
    }
    final v = d.vehicle;
    if (v != null) {
      final opts = CircleOptions(
        geometry: LatLng(v.lat, v.lng),
        circleRadius: 9,
        circleColor: hex,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      );
      if (_bus == null) {
        _bus = await c.addCircle(opts);
      } else {
        await c.updateCircle(_bus!, opts);
      }
    } else if (_bus != null) {
      await c.removeCircle(_bus!);
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
