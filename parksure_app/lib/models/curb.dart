import 'package:latlong2/latlong.dart';

import 'verdict.dart';

/// One curb side on the map: a GeoJSON Feature from `GET /api/curbs?bbox=`.
class Curb {
  const Curb({
    required this.segmentId,
    required this.side,
    required this.status,
    this.reason,
    this.validUntil,
    required this.lines,
  });

  final int segmentId;
  final String side;
  final ParkingStatus status;
  final String? reason;
  final DateTime? validUntil;

  /// LineString → one entry; MultiLineString → several.
  final List<List<LatLng>> lines;

  factory Curb.fromFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    return Curb(
      segmentId: props['segmentId'] as int,
      side: props['side'] as String,
      status: ParkingStatus.fromApi(props['status'] as String?),
      reason: props['reason'] as String?,
      validUntil: props['validUntil'] == null ? null : DateTime.parse(props['validUntil'] as String),
      lines: _parseGeometry(feature['geometry'] as Map<String, dynamic>?),
    );
  }

  static List<List<LatLng>> _parseGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return const [];
    List<LatLng> line(List coords) =>
        coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

    return switch (geometry['type']) {
      'LineString' => [line(geometry['coordinates'] as List)],
      'MultiLineString' => (geometry['coordinates'] as List).map((l) => line(l as List)).toList(),
      _ => const [],
    };
  }
}

/// The whole map response.
class CurbMap {
  const CurbMap({required this.curbs, required this.truncated, this.evaluatedAt});

  final List<Curb> curbs;

  /// True when the view holds too many curbs: the app should ask the user to zoom in.
  final bool truncated;
  final DateTime? evaluatedAt;

  factory CurbMap.fromJson(Map<String, dynamic> json) => CurbMap(
        curbs: ((json['features'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Curb.fromFeature)
            .toList(),
        truncated: json['truncated'] as bool? ?? false,
        evaluatedAt: json['evaluatedAt'] == null ? null : DateTime.parse(json['evaluatedAt'] as String),
      );
}
