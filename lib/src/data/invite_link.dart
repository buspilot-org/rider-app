/// Invite links: `https://buspilot.org/join/<code>`.
const inviteHost = 'buspilot.org';

/// The invite code in a scanned or opened value: a join link or a bare code.
/// Returns null for anything else (other URLs, empty text).
String? inviteCodeFrom(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    final hostOk = uri.host == inviteHost || uri.host == 'www.$inviteHost';
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == 'https' &&
        hostOk &&
        segments.length == 2 &&
        segments.first == 'join') {
      return _codeOrNull(segments[1]);
    }
    return null;
  }
  return _codeOrNull(text);
}

/// Codes are letters and digits, typed with or without dashes and spaces.
String? _codeOrNull(String value) {
  final String v;
  try {
    v = Uri.decodeComponent(value).trim();
  } on ArgumentError {
    return null; // A malformed %-escape.
  }
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 \-]{3,40}$').hasMatch(v)) return null;
  return v.toUpperCase();
}
