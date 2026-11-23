import 'package:buspilot_rider/src/data/ewkb.dart';
import 'package:buspilot_rider/src/data/invite_link.dart';
import 'package:buspilot_rider/src/data/models.dart';
import 'package:buspilot_rider/src/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';

void main() {
  group('inviteCodeFrom', () {
    test('join links and bare codes', () {
      expect(inviteCodeFrom('https://buspilot.org/join/DEMO-KOBE-2026'), 'DEMO-KOBE-2026');
      expect(inviteCodeFrom('https://buspilot.org/join/demo-kobe-2026/'), 'DEMO-KOBE-2026');
      expect(inviteCodeFrom('  abcde-fghjk '), 'ABCDE-FGHJK');
    });

    test('rejects other links and junk', () {
      expect(inviteCodeFrom('https://evil.example/join/DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('http://buspilot.org/join/DEMO-KOBE-2026'), isNull);
      expect(inviteCodeFrom('https://buspilot.org/other/DEMO'), isNull);
      expect(inviteCodeFrom('WIFI:S:net;T:WPA;P:secret;;'), isNull);
      expect(inviteCodeFrom(''), isNull);
      // A malformed %-escape must not throw.
      expect(inviteCodeFrom('AB%ZZ-CDEFG'), isNull);
      expect(inviteCodeFrom('https://buspilot.org/join/AB%ZZ'), isNull);
    });
  });

  group('decodeEwkb', () {
    test('point and line string with SRID (as returned by PostgREST)', () {
      // SRID=4326;POINT(135.1953 34.7067)
      final p = decodeEwkb('0101000020E6100000151DC9E53FE66040A60A4625755A4140');
      expect(p, hasLength(1));
      expect(p!.single.lng, closeTo(135.1953, 1e-9));
      expect(p.single.lat, closeTo(34.7067, 1e-9));

      final line = decodeEwkb(
        '0102000020E610000002000000151DC9E53FE66040A60A4625755A4140'
        'E3A59BC420E66040A8C64B3789594140',
      );
      expect(line, hasLength(2));
      expect(line![1].lng, closeTo(135.1915, 1e-9));
    });

    test('garbage is null', () {
      expect(decodeEwkb('zz'), isNull);
      expect(decodeEwkb(null), isNull);
      expect(decodeEwkb('0101000020E6100000'), isNull);
    });
  });

  test('service calendar: weekdays, range and exceptions', () {
    final cal = Catalog(demoCatalog()).calendars.single;
    expect(cal.runsOn(DateTime.utc(2026, 11, 23)), isTrue); // Monday
    expect(cal.runsOn(DateTime.utc(2026, 11, 28)), isFalse); // Saturday
    expect(cal.runsOn(DateTime.utc(2026, 12, 24)), isFalse); // winter break
    expect(cal.runsOn(DateTime.utc(2027, 1, 8)), isTrue);
    expect(cal.runsOn(DateTime.utc(2027, 4, 1)), isFalse); // after the end
  });

  test('map visibility follows the server rule', () {
    final json = demoCatalog();
    expect(Catalog(json).canSeeMap(Catalog(json).routes.single), isFalse);
    (json['routes'] as List).single['visibility'] = 'invited_map';
    expect(Catalog(json).canSeeMap(Catalog(json).routes.single), isFalse);
    (json['audience_routes'] as List).single['can_see_map'] = true;
    expect(Catalog(json).canSeeMap(Catalog(json).routes.single), isTrue);
    (json['routes'] as List).single['visibility'] = 'invited_eta';
    expect(Catalog(json).canSeeMap(Catalog(json).routes.single), isFalse);
  });

  test('route colours keep readable contrast', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final ok = routeColors('1E6FD9', 'FFFFFF', scheme);
    expect(ok.foreground, const Color(0xFFFFFFFF));
    // Yellow on white is unreadable: falls back to black text.
    final fixed = routeColors('FFEB3B', 'FFFFFF', scheme);
    expect(fixed.foreground, Colors.black);
  });
}
