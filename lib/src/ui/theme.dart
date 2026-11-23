import 'package:material_ui/material_ui.dart';

/// Buspilot app chrome: neutral, so operator colours stand out on cards.
const _seed = Color(0xFF1F5C7A);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
  );
}

/// Parses "RRGGBB" (with or without #).
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(h)) return null;
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Background and text colour for a route badge. Uses the route's colours when
/// their contrast is at least 4.5:1 (WCAG AA), else picks black or white text.
({Color background, Color foreground}) routeColors(
  String? color,
  String? textColor,
  ColorScheme scheme,
) {
  final bg = parseHexColor(color) ?? scheme.primary;
  final fg = parseHexColor(textColor);
  if (fg != null && _contrast(bg, fg) >= 4.5) {
    return (background: bg, foreground: fg);
  }
  final white = _contrast(bg, Colors.white);
  final black = _contrast(bg, Colors.black);
  return (background: bg, foreground: white >= black ? Colors.white : Colors.black);
}
