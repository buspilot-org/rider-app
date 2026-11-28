// The bus marker labels drawn in code (brand README, Open items): the
// yamabuki "あと5分" label (App board) and the "+5分" delayed badge (Icons
// board), with the bus kept in the centre of the image.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:buspilot_rider/src/state/app_state.dart';
import 'package:buspilot_rider/src/ui/bus_marker.dart';
import 'package:buspilot_rider/src/ui/theme.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  return (await codec.getNextFrame()).image;
}

/// The colour of the pixel at ([x], [y]).
Future<Color> _pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The brand font instead of the test font, so the dumped images
  // (BUS_MARKER_PNG) show the real text.
  setUpAll(() async {
    final loader = FontLoader(brandFontFamily)..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Bold.ttf'));
    await loader.load();
  });

  testWidgets('the plain marker without labels keeps its size', (tester) async {
    await tester.runAsync(() async {
      final png = await paintBusMarker(markerAsset: 'assets/markers/bus-marker.png', colors: BuspilotColors.light);
      final image = await _decode(png);
      expect(image.width, 138);
      expect(image.height, 138);
    });
  });

  testWidgets('labels: ETA in yamabuki on the left, delay badge top right, bus in the centre', (tester) async {
    await tester.runAsync(() async {
      for (final colors in [BuspilotColors.light, BuspilotColors.dark]) {
        final png = await paintBusMarker(
          markerAsset: 'assets/markers/bus-marker.png',
          colors: colors,
          eta: 'あと5分',
          delay: '+5分',
        );
        final out = Platform.environment['BUS_MARKER_PNG'];
        if (out != null) File('$out-${colors == BuspilotColors.dark ? 'dark' : 'light'}.png').writeAsBytesSync(png);
        final image = await _decode(png);
        // Wider than the marker, and symmetric so the anchor is the bus.
        expect(image.width, greaterThan(138));
        expect(image.width.isEven, isTrue);
        // The centre is the bus tile's white dot (the stop in the symbol)
        // or the asagi tile: never a label colour.
        final centre = await _pixel(image, image.width ~/ 2, image.height ~/ 2);
        expect(centre, isNot(colors.accent));
        expect(centre, isNot(colors.delayed));
        // Left of the tile, on the centre line: the yamabuki label.
        var label = false;
        for (var x = 0; x < image.width ~/ 2 - 3 * 23 && !label; x += 3) {
          label = await _pixel(image, x, image.height ~/ 2) == colors.accent;
        }
        expect(label, isTrue);
        // Right of the tile, near the top: the delayed badge.
        var badge = false;
        for (var x = image.width ~/ 2 + 3 * 23; x < image.width && !badge; x += 3) {
          for (var y = 0; y < image.height ~/ 2 && !badge; y += 3) {
            badge = await _pixel(image, x, y) == colors.delayed;
          }
        }
        expect(badge, isTrue);
      }
    });
  });

  testWidgets('no-signal and arriving markers can carry labels too', (tester) async {
    await tester.runAsync(() async {
      final png = await paintBusMarker(
        markerAsset: 'assets/markers/bus-arriving.png',
        colors: BuspilotColors.light,
        delay: '+12 min',
      );
      final image = await _decode(png);
      expect(image.height, greaterThanOrEqualTo(168));
    });
  });

  test('dark maps only with a dark style URL', () async {
    final store = await freshStore();
    final light = AppState(api: FakeApi(), store: store, mapStyleUrl: 'light.json');
    expect(light.mapIsDark(Brightness.dark), isFalse);
    expect(light.mapStyleFor(Brightness.dark), 'light.json');
    final both = AppState(api: FakeApi(), store: store, mapStyleUrl: 'light.json', mapStyleUrlDark: 'dark.json');
    expect(both.mapIsDark(Brightness.dark), isTrue);
    expect(both.mapStyleFor(Brightness.dark), 'dark.json');
    expect(both.mapStyleFor(Brightness.light), 'light.json');
  });
}
