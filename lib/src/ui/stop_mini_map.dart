import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../data/ewkb.dart';
import '../state/app_state.dart';

/// A small map of one stop: no other stops, no bus. Shown only when the
/// server lets this device read the stop's location (`stop_location`);
/// otherwise nothing is shown. For arrival-time-only audiences the server is
/// to return the location of the followed stop only.
class StopMiniMap extends StatefulWidget {
  const StopMiniMap({super.key, required this.stopId, this.height = 160});

  final String stopId;
  final double height;

  @override
  State<StopMiniMap> createState() => _StopMiniMapState();
}

class _StopMiniMapState extends State<StopMiniMap> {
  LngLat? _point;

  @override
  void initState() {
    super.initState();
    if (AppConfig.mapStyleUrl.isNotEmpty) _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.read(context).api.fetchMapData(
        shapeId: null,
        stopIds: [widget.stopId],
      );
      if (mounted) setState(() => _point = data.stops[widget.stopId]);
    } catch (_) {
      // Offline or not allowed: no map.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    if (p == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final hex = '#${(scheme.primary.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: widget.height,
          child: MapLibreMap(
            styleString: AppConfig.mapStyleUrl,
            initialCameraPosition: CameraPosition(target: LatLng(p.lat, p.lng), zoom: 15.5),
            myLocationEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: () => _controller?.addCircle(CircleOptions(
              geometry: LatLng(p.lat, p.lng),
              circleRadius: 8,
              circleColor: '#FFFFFF',
              circleStrokeColor: hex,
              circleStrokeWidth: 4,
            )),
          ),
        ),
      ),
    );
  }

  MapLibreMapController? _controller;
}
