import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'ewkb.dart';
import 'models.dart';

/// [BuspilotApi] on Supabase (PostgREST + Auth).
class SupabaseApi implements BuspilotApi {
  SupabaseApi(this.client);

  final SupabaseClient client;

  static const _timeout = Duration(seconds: 15);

  String get _uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('not signed in');
    return id;
  }

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(_timeout);
    } on SocketException catch (e) {
      throw OfflineException(e);
    } on TimeoutException catch (e) {
      throw OfflineException(e);
    } on AuthRetryableFetchException catch (e) {
      throw OfflineException(e);
    } on http.ClientException catch (e) {
      throw OfflineException(e);
    }
  }

  @override
  Future<String> ensureSignedIn() => _run(() async {
    final user = client.auth.currentUser;
    if (user != null) return user.id;
    final res = await client.auth.signInAnonymously();
    return res.user!.id;
  });

  @override
  Future<void> touchDevice({
    required String platform,
    required String language,
  }) => _run(() async {
    await client.from('device').upsert({
      'id': _uid,
      'platform': platform,
      'language': language,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  @override
  Future<void> setPushToken(String? token) => _run(() async {
    await client.from('device').update({'push_token': token}).eq('id', _uid);
  });

  @override
  Future<RedeemResult> redeemInviteCode(String code) => _run(() async {
    final rows = await client.rpc('redeem_invite_code', params: {'p_code': code});
    final row = (rows as List).isEmpty ? const {} : rows.first as Map;
    final status = switch (row['status']) {
      'joined' => RedeemStatus.joined,
      'already_member' => RedeemStatus.alreadyMember,
      'revoked' => RedeemStatus.revoked,
      'rate_limited' => RedeemStatus.rateLimited,
      _ => RedeemStatus.invalid,
    };
    return RedeemResult(status, operatorId: row['operator_id'] as String?);
  });

  @override
  Future<Json> fetchCatalog() => _run(() async {
    final results = await Future.wait<List<dynamic>>([
      client
          .from('operator')
          .select(
            'id,name,timezone,languages,branding,default_visibility,'
            'operator_link(id,label,url,sort_order)',
          ),
      client
          .from('route')
          .select(
            'id,operator_id,name,short_name,color,text_color,visibility,sort_order,'
            'trip_pattern(id,name,shape_id,direction,'
            'pattern_stop(stop_sequence,stop_id,arrival_offset,stop(name)),'
            'trip(id,start_time,service_calendar_id,headsign))',
          ),
      client.from('audience_route').select('route_id,can_see_map'),
      client
          .from('service_calendar')
          .select(
            'id,operator_id,name,weekdays,start_date,end_date,skip_national_holidays,'
            'calendar_exception(start_date,end_date,type,reason)',
          ),
      client
          .from('membership')
          .select('id,operator_id,audience_id,revoked_at')
          .eq('device_id', _uid),
      client
          .from('subscription')
          .select(
            'id,operator_id,pattern_id,stop_sequence,trigger,trigger_value,'
            'notify_passed,muted_until',
          )
          .eq('device_id', _uid),
    ]);
    // Posts of joined operators and of followed routes only: RLS also
    // returns every public operator's posts, which would crowd out the
    // device's own under the limit.
    final members = {
      for (final m in results[4])
        if ((m as Map)['revoked_at'] == null) m['operator_id'] as String,
    };
    final followedPatterns = {for (final s in results[5]) (s as Map)['pattern_id'] as String};
    final followedRoutes = {
      for (final r in results[1])
        if (((r as Map)['trip_pattern'] as List? ?? const [])
            .any((p) => followedPatterns.contains((p as Map)['id'])))
          r['id'] as String,
    };
    final filters = [
      if (members.isNotEmpty) 'operator_id.in.(${members.join(',')})',
      if (followedRoutes.isNotEmpty) 'route_id.in.(${followedRoutes.join(',')})',
    ];
    final posts = filters.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
              .from('post')
              .select('id,operator_id,route_id,title,body,published_at')
              .or(filters.join(','))
              .order('published_at', ascending: false)
              .limit(100);
    return {
      'operators': results[0],
      'routes': results[1],
      'audience_routes': results[2],
      'calendars': results[3],
      'memberships': results[4],
      'subscriptions': results[5],
      'posts': posts,
    };
  });

  @override
  Future<List<Json>> fetchTripInstances({
    required List<String> routeIds,
    required List<String> serviceDates,
  }) => _run(() async {
    if (routeIds.isEmpty || serviceDates.isEmpty) return const <Json>[];
    final rows = await client
        .from('trip_instance')
        .select(
          'id,trip_id,pattern_id,route_id,service_date,kind,status,'
          'off_route_since,progress_at,title,updated_at,'
          'stop_event(stop_sequence,state,eta,arrived_at,departed_at,passed_at,updated_at)',
        )
        .inFilter('route_id', routeIds)
        .inFilter('service_date', serviceDates);
    return [for (final r in rows) r.cast<String, dynamic>()];
  });

  @override
  Future<MapData> fetchMapData({
    required String? shapeId,
    required List<String> stopIds,
  }) => _run(() async {
    final shapeRows = shapeId == null
        ? const <Map<String, dynamic>>[]
        : await client.from('shape').select('geom').eq('id', shapeId);
    final stopRows = stopIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
              .from('stop_location')
              .select('id,location')
              .inFilter('id', stopIds);
    return MapData(
      line: shapeRows.isEmpty ? const [] : (decodeEwkb(shapeRows.first['geom']) ?? const []),
      stops: {
        for (final r in stopRows)
          if (decodeEwkb(r['location']) case [final p]) r['id'] as String: p,
      },
    );
  });

  @override
  Future<VehiclePosition?> fetchVehicle(String tripInstanceId) => _run(() async {
    final rows = await client
        .from('vehicle_state')
        .select('location,recorded_at')
        .eq('trip_instance_id', tripInstanceId);
    if (rows.isEmpty) return null;
    final p = decodeEwkb(rows.first['location']);
    if (p == null || p.isEmpty) return null;
    return VehiclePosition(
      p.first,
      DateTime.tryParse(rows.first['recorded_at'] as String? ?? ''),
    );
  });

  @override
  Future<void> saveSubscription(Subscription subscription) => _run(() async {
    final row = subscription.toJson()..['device_id'] = _uid;
    row.remove('id');
    await client
        .from('subscription')
        .upsert(row, onConflict: 'device_id,pattern_id,stop_sequence');
  });

  @override
  Future<void> deleteSubscription(String id) => _run(() async {
    await client.from('subscription').delete().eq('id', id);
  });

  @override
  Future<void> leaveOperator(String operatorId) => _run(() async {
    await client
        .from('membership')
        .delete()
        .eq('device_id', _uid)
        .eq('operator_id', operatorId)
        .isFilter('revoked_at', null);
  });

  @override
  Future<void> deleteMyData() => _run(() async {
    await client.from('device').delete().eq('id', _uid);
    await client.auth.signOut();
  });
}
