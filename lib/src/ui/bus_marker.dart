import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Pixel ratio of the painted marker images (the 3.0x marker assets).
const busMarkerPixelRatio = 3.0;

/// The bus marker with its labels, drawn in code because they contain text
/// (brand README, "Open items"):
///
/// - [eta]: the yamabuki label on the left, "あと5分" (brand App board and
///   Colour board "On the map"): accent fill, onAccent text.
/// - [delay]: the badge at the top right, "+5分" (brand Icons board,
///   "Delayed · badge"): delayed fill, onStatus text, white border like the
///   marker's.
///
/// [markerAsset] is one of the marker PNGs (its 3.0x variant is used). The
/// image is symmetric around the bus, so the symbol's anchor (the centre)
/// stays on the bus position. [colors] is the palette of the map (light or
/// dark), not necessarily of the app.
Future<Uint8List> paintBusMarker({
  required String markerAsset,
  required BuspilotColors colors,
  String? eta,
  String? delay,
}) async {
  final marker = await _loadImage(_variant3x(markerAsset));
  try {
    return await _paint(marker, colors: colors, eta: eta, delay: delay);
  } finally {
    marker.dispose();
  }
}

/// 'assets/markers/bus-marker.png' -> 'assets/markers/3.0x/bus-marker.png'.
String _variant3x(String asset) {
  final slash = asset.lastIndexOf('/');
  return '${asset.substring(0, slash)}/3.0x${asset.substring(slash)}';
}

Future<ui.Image> _loadImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// White border around the badge, as the 3 px border of the bus tile.
const _badgeBorder = 2.0;

TextPainter _text(String text, double size, Color color) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      fontFamily: brandFontFamily,
      fontFamilyFallback: const ['Hiragino Maru Gothic ProN', 'BIZ UDPGothic', 'sans-serif'],
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: color,
    ),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

Future<Uint8List> _paint(ui.Image marker, {required BuspilotColors colors, String? eta, String? delay}) async {
  // Everything in dp around the bus centre (0, 0).
  final markerSize = marker.width / busMarkerPixelRatio;
  final half = markerSize / 2;
  // The tile without the halo or border: 40 dp (brand README, Map markers).
  const tileHalf = 20.0;
  final markerRect = Rect.fromCenter(center: Offset.zero, width: markerSize, height: markerSize);
  var bounds = markerRect;

  // ETA label: label style (14, bold), tucked under the tile's left edge.
  final etaText = eta == null ? null : _text(eta, 14, colors.onAccent);
  Rect? etaRect;
  if (etaText != null) {
    final w = etaText.width + 2 * 8;
    final h = etaText.height + 2 * 2;
    final right = -tileHalf + 6;
    etaRect = Rect.fromLTWH(right - w, -h / 2, w, h);
    bounds = bounds.expandToInclude(etaRect);
  }

  // Delayed badge: caption size (12, the minimum), bold, on the top-right
  // corner of the tile.
  final delayText = delay == null ? null : _text(delay, 12, colors.onStatus);
  Rect? delayRect;
  if (delayText != null) {
    final w = delayText.width + 2 * 6 + 2 * _badgeBorder;
    final h = delayText.height + 2 * _badgeBorder;
    delayRect = Rect.fromLTWH(tileHalf - 12, -tileHalf - h / 2 + 2, w, h);
    bounds = bounds.expandToInclude(delayRect);
  }

  // Symmetric around the bus, so the image centre is the bus.
  final hx = math.max(half, math.max(-bounds.left, bounds.right)).ceilToDouble();
  final hy = math.max(half, math.max(-bounds.top, bounds.bottom)).ceilToDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(busMarkerPixelRatio)
    ..translate(hx, hy);

  if (etaRect != null && etaText != null) {
    final pill = RRect.fromRectAndRadius(etaRect, Radius.circular(etaRect.height / 2));
    canvas.drawRRect(pill, Paint()..color = colors.accent);
    etaText.paint(canvas, Offset(etaRect.left + 8, etaRect.top + 2));
  }

  canvas.drawImageRect(
    marker,
    Rect.fromLTWH(0, 0, marker.width.toDouble(), marker.height.toDouble()),
    markerRect,
    Paint()..filterQuality = FilterQuality.high,
  );

  if (delayRect != null && delayText != null) {
    final outer = RRect.fromRectAndRadius(delayRect, Radius.circular(delayRect.height / 2));
    canvas.drawRRect(outer, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(outer.deflate(_badgeBorder), Paint()..color = colors.delayed);
    delayText.paint(canvas, Offset(delayRect.left + _badgeBorder + 6, delayRect.top + _badgeBorder));
  }

  etaText?.dispose();
  delayText?.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage((2 * hx * busMarkerPixelRatio).round(), (2 * hy * busMarkerPixelRatio).round());
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
