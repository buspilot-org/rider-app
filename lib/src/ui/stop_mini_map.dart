import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/ewkb.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// A small map of one stop: no other stops, no bus. Shown only when the
/// server lets this device read the stop's location (`stop_location`).
///
/// For arrival-time-only audiences the server returns the location of
/// followed stops only, and only of the first two followed stops per
/// operator. Without a location this says why in one line (follow the stop,
/// or the two-stop limit); offline, nothing is shown.
class StopMiniMap extends StatefulWidget {
  const StopMiniMap({
    super.key,
    required this.stopId,
    required this.followed,
    this.height = 160,
  });

  final String stopId;

  /// Whether the device follows this stop (decides the note without a map).
  final bool followed;
  final double height;

  @override
  State<StopMiniMap> createState() => _StopMiniMapState();
}

class _StopMiniMapState extends State<StopMiniMap> {
  LngLat? _point;

  /// The server answered (with or without a location).
  bool _loaded = false;
  bool _started = false;

  String get _style => AppScope.read(context).mapStyleUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_style.isNotEmpty) _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.read(context).api.fetchMapData(
        shapeId: null,
        stopIds: [widget.stopId],
      );
      if (mounted) {
        setState(() {
          _point = data.stops[widget.stopId];
          _loaded = true;
        });
      }
    } catch (_) {
      // Offline: no map and no note.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    if (p == null) {
      if (!_loaded) return const SizedBox.shrink();
      return Padding(
        key: const Key('mini-map-note'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Icon(Icons.map_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.followed ? context.l10n.miniMapLimit : context.l10n.miniMapFollowHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: widget.height,
          child: MapLibreMap(
            styleString: _style,
            initialCameraPosition: CameraPosition(target: LatLng(p.lat, p.lng), zoom: 15.5),
            myLocationEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: () => _controller?.addSymbol(SymbolOptions(
              geometry: LatLng(p.lat, p.lng),
              iconImage: 'assets/markers/my-stop.png',
            )),
          ),
        ),
      ),
    );
  }

  MapLibreMapController? _controller;
}
