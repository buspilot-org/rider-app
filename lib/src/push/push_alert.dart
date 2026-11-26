/// An arrival alert from the engine (FCM `data`, buspilot-org/server
/// engine/README.md "Push message format", version 1).
enum AlertKind { approaching, arrived, passed, delayed, cancelled }

/// Android notification channels the engine sends to (`channel_id`).
const arrivalAlertsChannel = 'arrival_alerts';
const tripChangesChannel = 'trip_changes';

class PushAlert {
  const PushAlert({
    required this.kind,
    this.routeId,
    this.patternId,
    this.stopId,
    this.stopSequence,
    this.tripInstanceId,
    this.title,
    this.body,
  });

  final AlertKind kind;
  final String? routeId;
  final String? patternId;
  final String? stopId;
  final int? stopSequence;
  final String? tripInstanceId;

  /// The localised notification text from the server (shown in the
  /// foreground).
  final String? title;
  final String? body;

  /// Parses FCM [data]. Returns null for anything the app does not know:
  /// a version other than "1", another message type, an unknown kind
  /// (later additions are ignored, not misread).
  static PushAlert? fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    if (data['v'] != '1' || data['type'] != 'stop_alert') return null;
    final kind = switch (data['kind']) {
      'approaching' => AlertKind.approaching,
      'arrived' => AlertKind.arrived,
      'passed' => AlertKind.passed,
      'delayed' => AlertKind.delayed,
      'cancelled' => AlertKind.cancelled,
      _ => null,
    };
    if (kind == null) return null;
    String? id(String key) {
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final seq = id('stop_sequence');
    return PushAlert(
      kind: kind,
      routeId: id('route_id'),
      patternId: id('pattern_id'),
      stopId: id('stop_id'),
      stopSequence: seq == null ? null : int.tryParse(seq),
      tripInstanceId: id('trip_instance_id'),
      title: title,
      body: body,
    );
  }
}
