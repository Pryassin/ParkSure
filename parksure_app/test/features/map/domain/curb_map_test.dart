import 'package:flutter_test/flutter_test.dart';
import 'package:parksure_app/core/domain/curb_status.dart';
import 'package:parksure_app/features/map/domain/curb_map.dart';
import 'package:parksure_app/features/map/domain/curb_segment.dart';

CurbSegment _segment(int id, CurbStatus status) => CurbSegment(
      segmentId: id,
      side: 'east',
      status: status,
      reason: '',
      points: const [],
    );

void main() {
  test('countByStatus counts each status and includes zeros', () {
    final map = CurbMap(
      evaluatedAt: DateTime(2026, 11, 6),
      isTruncated: false,
      segments: [
        _segment(1, CurbStatus.allowed),
        _segment(2, CurbStatus.allowed),
        _segment(3, CurbStatus.notAllowed),
      ],
    );

    expect(map.countByStatus, {
      CurbStatus.allowed: 2,
      CurbStatus.conditions: 0,
      CurbStatus.notAllowed: 1,
      CurbStatus.unknown: 0,
    });
  });

  test('isEmpty is true when there are no segments', () {
    final map = CurbMap(
      evaluatedAt: DateTime(2026, 11, 6),
      isTruncated: false,
      segments: const [],
    );
    expect(map.isEmpty, isTrue);
  });
}
