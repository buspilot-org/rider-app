/// The public Storage path of operator branding images
/// (`operator-branding/<operator_id>/…` on the Supabase project).
const brandingPath = '/storage/v1/object/public/operator-branding/';

/// [url] if it is an operator branding image on the Buspilot backend
/// ([backendUrl], the Supabase project), else null.
///
/// Riders' phones load images only from there, never from a host the
/// operator picked (that host would see every rider's IP address and when
/// they open the app). The server accepts any https URL in
/// `branding.logo_url` / `cover_url`, so the app checks: same scheme, host
/// and port as the backend, and the operator's own folder in the
/// `operator-branding` bucket.
String? brandingImageUrl(
  String? url, {
  required String backendUrl,
  required String operatorId,
}) {
  if (url == null || backendUrl.isEmpty || operatorId.isEmpty) return null;
  final uri = Uri.tryParse(url);
  final backend = Uri.tryParse(backendUrl);
  if (uri == null || backend == null || backend.host.isEmpty) return null;
  if (uri.scheme != backend.scheme ||
      uri.host != backend.host ||
      uri.port != backend.port ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  // Decoded segments, so "%2F" or ".." cannot leave the operator's folder.
  final segments = uri.pathSegments;
  const prefix = ['storage', 'v1', 'object', 'public', 'operator-branding'];
  if (segments.length < prefix.length + 2) return null;
  for (var i = 0; i < prefix.length; i++) {
    if (segments[i] != prefix[i]) return null;
  }
  if (segments[prefix.length] != operatorId) return null;
  final rest = segments.skip(prefix.length + 1);
  if (rest.any((s) => s.isEmpty || s == '.' || s == '..' || s.contains('/'))) return null;
  return uri.toString();
}
