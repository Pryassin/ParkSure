import '../../../core/api/json_parsing.dart';
import '../../../core/domain/geo_point.dart';
import '../domain/curb_map.dart';
import '../domain/curb_segment.dart';

/// Reads the GeoJSON FeatureCollection from `GET /api/curbs?bbox=...`.
CurbMap curbMapFromJson(Map<String, dynamic> json) {
  final features = (json['features'] as List).cast<Map<String, dynamic>>();
  return CurbMap(
    evaluatedAt: DateTime.parse(json['evaluatedAt'] as String),
    isTruncated: json['truncated'] as bool? ?? false,
    segments: [
      for (final feature in features) ?_segmentFromFeature(feature),
    ],
  );
}

/// Null when the geometry is not a line we can draw; that curb is skipped
/// instead of breaking the whole map.
CurbSegment? _segmentFromFeature(Map<String, dynamic> feature) {
  final geometry = feature['geometry'] as Map<String, dynamic>?;
  if (geometry == null || geometry['type'] != 'LineString') return null;

  final coordinates = (geometry['coordinates'] as List).cast<List>();
  if (coordinates.length < 2) return null;

  final props = feature['properties'] as Map<String, dynamic>;
  return CurbSegment(
    segmentId: props['segmentId'] as int,
    side: props['side'] as String,
    status: parseStatus(props['status']),
    reason: props['reason'] as String? ?? '',
    validUntil: parseTime(props['validUntil']),
    // GeoJSON order is [lon, lat].
    points: [
      for (final c in coordinates) GeoPoint(toDouble(c[1]), toDouble(c[0])),
    ],
  );
}
