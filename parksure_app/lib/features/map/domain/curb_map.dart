import '../../../core/domain/curb_status.dart';
import 'curb_segment.dart';

/// Every curb inside the visible map area, evaluated at one moment.
class CurbMap {
  const CurbMap({
    required this.segments,
    required this.evaluatedAt,
    required this.isTruncated,
  });

  final List<CurbSegment> segments;
  final DateTime evaluatedAt;

  /// True when there were too many curbs to send: the user should zoom in.
  final bool isTruncated;

  bool get isEmpty => segments.isEmpty;

  /// How many curbs have each status. Every status is present, even at 0.
  /// Feeds the legend at the bottom of the map ("12 · 1 · 89 · 307").
  Map<CurbStatus, int> get countByStatus {
    final counts = {for (final status in CurbStatus.values) status: 0};
    for (final segment in segments) {
      counts[segment.status] = counts[segment.status]! + 1;
    }
    return counts;
  }
}
