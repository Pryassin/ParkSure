import '../../../core/domain/curb_status.dart';
import '../../../core/domain/geo_point.dart';

/// One side of one street block, as drawn on the map.
class CurbSegment {
  const CurbSegment({
    required this.segmentId,
    required this.side,
    required this.status,
    required this.reason,
    required this.points,
    this.validUntil,
  });

  final int segmentId;

  /// Which side of the street, e.g. "east".
  final String side;
  final CurbStatus status;

  /// Short explanation, e.g. "No restriction active now".
  final String reason;

  /// The line to draw, in order.
  final List<GeoPoint> points;

  /// When [status] stops being true. Null = no known end.
  final DateTime? validUntil;
}
