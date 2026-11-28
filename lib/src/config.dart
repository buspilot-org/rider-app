/// Build-time configuration, passed with `--dart-define-from-file`.
/// See `config/example.json`; the real file (`config/local.json`) is
/// git-ignored.
class AppConfig {
  /// Supabase API URL, e.g. http://127.0.0.1:55321 for the local stack.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (anon) key. Public by design; RLS protects data.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// MapLibre style URL. Empty: no map, the app shows arrival times only.
  static const mapStyleUrl = String.fromEnvironment('MAP_STYLE_URL');

  /// Optional dark MapLibre style for the dark theme (brand Colour board,
  /// "On the map"). Empty: the light style in both themes.
  static const mapStyleUrlDark = String.fromEnvironment('MAP_STYLE_URL_DARK');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
