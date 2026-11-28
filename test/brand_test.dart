// The Buspilot brand on the screens: the Arrival symbol instead of a generic
// bus icon, and yamabuki (not red) for counts.
import 'package:buspilot_rider/src/ui/theme.dart';
import 'package:buspilot_rider/src/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_api.dart';
import 'fakes/harness.dart';

void main() {
  setUpAll(initTimeZones);

  testWidgets('onboarding shows the Arrival symbol, not a bus icon', (tester) async {
    await pumpApp(tester, api: FakeApi(), onboarded: false, language: null);
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.byIcon(Icons.directions_bus), findsNothing);
  });

  testWidgets('home: symbol next to the name, and in the empty state', (tester) async {
    await pumpApp(tester, api: FakeApi());
    // App bar and "no bus services yet".
    expect(find.byType(BrandMark), findsNWidgets(2));
    expect(find.byIcon(Icons.directions_bus_outlined), findsNothing);
  });

  test('badges are yamabuki with dark text in both themes', () {
    for (final b in Brightness.values) {
      final t = buildTheme(b);
      final bp = t.extension<BuspilotColors>()!;
      expect(t.badgeTheme.backgroundColor, bp.accent);
      expect(t.badgeTheme.textColor, bp.onAccent);
    }
  });

  test('errors and cancellations use the brand crimson, not Material red (brand#4 D1)', () {
    for (final b in Brightness.values) {
      final t = buildTheme(b);
      final bp = t.extension<BuspilotColors>()!;
      expect(t.colorScheme.error, bp.error);
      expect(t.colorScheme.onError, bp.onStatus);
      expect(t.colorScheme.errorContainer, bp.errorTint);
      expect(t.colorScheme.onErrorContainer, bp.errorText);
    }
  });
}
