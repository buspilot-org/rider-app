/// Invite links. Canonical (README): `https://buspilot.org/join#code=<code>`.
/// The code is in the fragment, which browsers never send to a server, and
/// buspilot.org is the host the app links (Android App Links, iOS Universal
/// Links) are verified for. Also accepted:
///
/// - `https://buspilot.org/join/<code>` (the first format, in the concept);
/// - `https://app.buspilot.org/join#code=<code>` (the admin console's
///   default before the canonical format was settled).
const inviteHost = 'buspilot.org';

const _hosts = {inviteHost, 'www.$inviteHost', 'app.$inviteHost'};

/// The invite code in a scanned or opened value: a join link or a bare code.
/// Returns null for anything else (other URLs, empty text).
String? inviteCodeFrom(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'https' || !_hosts.contains(uri.host)) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.first != 'join') return null;
    // https://<host>/join#code=<code>
    if (segments.length == 1 && uri.fragment.isNotEmpty) {
      final String? code;
      try {
        code = Uri.splitQueryString(uri.fragment)['code'];
      } on ArgumentError {
        return null; // A malformed %-escape.
      }
      return code == null ? null : _codeOrNull(code, decoded: true);
    }
    // https://buspilot.org/join/<code> (not on the admin console host).
    if (segments.length == 2 && uri.host != 'app.$inviteHost' && !uri.hasFragment) {
      return _codeOrNull(segments[1]);
    }
    return null;
  }
  return _codeOrNull(text);
}

/// Codes are letters and digits, typed with or without dashes and spaces.
String? _codeOrNull(String value, {bool decoded = false}) {
  final String v;
  try {
    v = (decoded ? value : Uri.decodeComponent(value)).trim();
  } on ArgumentError {
    return null; // A malformed %-escape.
  }
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 \-]{3,40}$').hasMatch(v)) return null;
  return v.toUpperCase();
}
