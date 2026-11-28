import 'package:material_ui/material_ui.dart';

import 'brand/buspilot_tokens.dart';

export 'brand/buspilot_tokens.dart' show BuspilotColors;

/// The brand font, bundled in assets/fonts/ (SIL OFL 1.1). Never loaded from
/// the network.
const brandFontFamily = 'M PLUS Rounded 1c';
const _fontFallback = ['Hiragino Maru Gothic ProN', 'BIZ UDPGothic', 'sans-serif'];

/// Buspilot app chrome from the brand tokens (asagi), so the app looks the
/// same as the admin console and the website.
ThemeData buildTheme(Brightness brightness) {
  final bp = brightness == Brightness.dark ? BuspilotColors.dark : BuspilotColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: bp.primary, brightness: brightness).copyWith(
    primary: bp.primary,
    onPrimary: bp.onPrimary,
    primaryContainer: bp.primaryTint,
    onPrimaryContainer: bp.onPrimaryTint,
    secondary: bp.primaryStrong,
    onSecondary: bp.onPrimary,
    secondaryContainer: bp.primaryTint,
    onSecondaryContainer: bp.onPrimaryTint,
    tertiary: bp.accent,
    onTertiary: bp.onAccent,
    surface: bp.surface,
    onSurface: bp.text,
    onSurfaceVariant: bp.textMuted,
    outlineVariant: bp.border,
    // The brand's calm crimson instead of Material red (brand#4 D1):
    // cancelled trips, holidays and delete actions.
    error: bp.error,
    onError: bp.onStatus,
    errorContainer: bp.errorTint,
    onErrorContainer: bp.errorText,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: brandFontFamily, fontFamilyFallback: _fontFallback);
  return base.copyWith(
    scaffoldBackgroundColor: bp.background,
    textTheme: _brandText(base.textTheme),
    // Counts and dots in yamabuki, not red (red reads as 'broken').
    badgeTheme: BadgeThemeData(backgroundColor: bp.accent, textColor: bp.onAccent),
    cardTheme: CardThemeData(color: bp.surface, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
    extensions: [bp],
  );
}

/// The brand type scale (brand tokens/typography.json, app sizes in sp):
/// display 32, title 22, subtitle 18, body 16, label 14, caption 12. Every
/// Material style maps to one of them; never smaller than 12.
TextTheme _brandText(TextTheme t) {
  TextStyle? s(TextStyle? x, double size, FontWeight w, double height) =>
      x?.copyWith(fontSize: size, fontWeight: w, height: height, letterSpacing: 0);
  return t.copyWith(
    displaySmall: s(t.displaySmall, 32, FontWeight.w800, 1.3),
    headlineSmall: s(t.headlineSmall, 22, FontWeight.w800, 1.4),
    titleLarge: s(t.titleLarge, 22, FontWeight.w800, 1.4),
    titleMedium: s(t.titleMedium, 18, FontWeight.w700, 1.5),
    titleSmall: s(t.titleSmall, 14, FontWeight.w700, 1.4),
    bodyLarge: s(t.bodyLarge, 16, FontWeight.w500, 1.7),
    bodyMedium: s(t.bodyMedium, 16, FontWeight.w500, 1.7),
    bodySmall: s(t.bodySmall, 12, FontWeight.w500, 1.5),
    labelLarge: s(t.labelLarge, 14, FontWeight.w700, 1.4),
    labelMedium: s(t.labelMedium, 14, FontWeight.w700, 1.4),
    labelSmall: s(t.labelSmall, 12, FontWeight.w500, 1.5),
  );
}

/// The brand colours of the current theme.
extension BuspilotTheme on BuildContext {
  BuspilotColors get brand {
    final colors = Theme.of(this).extension<BuspilotColors>();
    assert(colors != null, 'Theme built without buildTheme(): no BuspilotColors');
    return colors ?? BuspilotColors.light;
  }
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
