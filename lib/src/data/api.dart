import 'ewkb.dart';
import 'models.dart';

/// Result of redeeming an invite code (public.redeem_invite_code).
enum RedeemStatus { joined, alreadyMember, invalid, revoked, rateLimited }

class RedeemResult {
  const RedeemResult(this.status, {this.operatorId});
  final RedeemStatus status;
  final String? operatorId;
}

/// Geometry for the route map. Empty when the device may not see the map
/// (RLS returns nothing).
class MapData {
  const MapData({this.line = const [], this.stops = const {}});

  final List<LngLat> line;

  /// stop id → position.
  final Map<String, LngLat> stops;

  bool get isEmpty => line.isEmpty && stops.isEmpty;
}

/// The bus position of an active trip (map level only).
class VehiclePosition {
  const VehiclePosition(this.position, this.recordedAt);
  final LngLat position;
  final DateTime? recordedAt;
}

/// Live state: trip progress, stop states, ETAs and the bus position.
///
/// Read from Supabase by polling for now. The engine's Live API
/// (`GET /v1/live/routes/:id`, SSE, authenticated with the Supabase access
/// token; internal/concept/engine.md) replaces it later behind this
/// interface; there are no Supabase Realtime subscriptions.
abstract class LiveSource {
  /// Trip instances with their stop events for [routeIds] on [serviceDates]
  /// ("2026-11-23").
  Future<List<Json>> fetchTripInstances({
    required List<String> routeIds,
    required List<String> serviceDates,
  });

  /// The bus of an active trip, if the device may see it on a map.
  Future<VehiclePosition?> fetchVehicle(String tripInstanceId);
}

/// Thrown when the network or the server is not reachable.
class OfflineException implements Exception {
  const OfflineException([this.cause]);
  final Object? cause;
  @override
  String toString() => 'OfflineException($cause)';
}

/// Everything the app reads and writes on the backend. RLS decides what the
/// anonymous device sees, so the app simply reads.
abstract class BuspilotApi implements LiveSource {
  /// Signs in anonymously unless a session exists; returns the user id.
  Future<String> ensureSignedIn();

  /// Creates or refreshes this device's row (`last_seen_at`, language,
  /// platform). Inactive devices are deleted after 90 days.
  Future<void> touchDevice({required String platform, required String language});

  /// Stores the push token (null removes it).
  Future<void> setPushToken(String? token);

  Future<RedeemResult> redeemInviteCode(String code);

  /// Operators, routes with patterns, stops and trips, calendars,
  /// memberships, subscriptions and posts, as raw JSON for [Catalog].
  Future<Json> fetchCatalog();

  /// Map geometry of a pattern (only returned at map level).
  Future<MapData> fetchMapData({
    required String? shapeId,
    required List<String> stopIds,
  });

  /// Creates or updates a subscription (one per pattern and stop sequence).
  Future<void> saveSubscription(Subscription subscription);

  Future<void> deleteSubscription(String id);

  /// Leaves an operator: deletes the device's memberships. The server drops
  /// subscriptions the device can no longer see.
  Future<void> leaveOperator(String operatorId);

  /// Deletes the device row (memberships and subscriptions follow by
  /// cascade) and signs out.
  Future<void> deleteMyData();
}
