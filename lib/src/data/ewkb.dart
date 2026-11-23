import 'dart:typed_data';

/// A longitude/latitude pair.
class LngLat {
  const LngLat(this.lng, this.lat);
  final double lng;
  final double lat;

  @override
  String toString() => 'LngLat($lng, $lat)';
}

/// Decodes the hex EWKB that PostgREST returns for PostGIS geography columns.
/// Supports Point and LineString (all the app needs); returns null otherwise.
List<LngLat>? decodeEwkb(Object? hex) {
  if (hex is! String || hex.length < 18 || hex.length.isOdd) return null;
  try {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    final data = ByteData.sublistView(bytes);
    final endian = bytes[0] == 1 ? Endian.little : Endian.big;
    var offset = 1;
    final rawType = data.getUint32(offset, endian);
    offset += 4;
    final hasSrid = rawType & 0x20000000 != 0;
    final hasZ = rawType & 0x80000000 != 0;
    final hasM = rawType & 0x40000000 != 0;
    final type = rawType & 0xFF;
    if (hasSrid) offset += 4;
    final dims = 2 + (hasZ ? 1 : 0) + (hasM ? 1 : 0);

    LngLat readPoint() {
      final p = LngLat(
        data.getFloat64(offset, endian),
        data.getFloat64(offset + 8, endian),
      );
      offset += 8 * dims;
      return p;
    }

    switch (type) {
      case 1:
        return [readPoint()];
      case 2:
        final n = data.getUint32(offset, endian);
        offset += 4;
        return [for (var i = 0; i < n; i++) readPoint()];
      default:
        return null;
    }
  } on RangeError {
    return null;
  } on FormatException {
    return null;
  }
}
