import 'package:flutter_test/flutter_test.dart';
import 'package:parksure/models/curb.dart';
import 'package:parksure/models/verdict.dart';

void main() {
  test('unrecognised status is unknown, never allowed', () {
    expect(ParkingStatus.fromApi('something_new'), ParkingStatus.unknown);
    expect(ParkingStatus.fromApi(null), ParkingStatus.unknown);
    expect(ParkingStatus.fromApi('not_allowed'), ParkingStatus.notAllowed);
  });

  test('parses an evaluated verdict', () {
    final v = Verdict.fromJson({
      'outcome': 'evaluated',
      'status': 'conditions',
      'reason': 'Paid parking',
      'unknownReason': null,
      'decidingCode': 'SD-123',
      'validUntil': '2026-10-14T18:00:00-04:00',
      'paymentRequired': true,
      'maxMinutes': 120,
      'activeCodes': ['SD-123'],
      'curb': {'segmentId': 7, 'side': 'left', 'streetName': 'Rue X', 'borough': 'B', 'distanceM': 3.2},
      'signs': [
        {'signId': 1, 'code': 'SD-123', 'text': 'PAID', 'confidence': 0.9},
      ],
      'disclaimer': 'Check the signs.',
    });
    expect(v.isAmbiguous, isFalse);
    expect(v.status, ParkingStatus.conditions);
    expect(v.curb!.segmentId, 7);
    expect(v.signs.single.confidence, 0.9);
    expect(v.validUntil!.toUtc().hour, 22);
  });

  test('parses an ambiguous verdict', () {
    final v = Verdict.fromJson({
      'outcome': 'ambiguous',
      'curbs': [
        {'segmentId': 1, 'side': 'left', 'distanceM': 4.0},
        {'segmentId': 2, 'side': 'right', 'distanceM': 5.1},
      ],
    });
    expect(v.isAmbiguous, isTrue);
    expect(v.status, ParkingStatus.unknown);
    expect(v.candidates.map((c) => c.segmentId), [1, 2]);
  });

  test('parses the bbox FeatureCollection', () {
    final map = CurbMap.fromJson({
      'type': 'FeatureCollection',
      'evaluatedAt': '2026-10-14T13:30:00+00:00',
      'truncated': false,
      'features': [
        {
          'type': 'Feature',
          'id': 7,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-73.56, 45.50],
              [-73.55, 45.51],
            ],
          },
          'properties': {'segmentId': 7, 'side': 'left', 'status': 'allowed', 'reason': 'ok', 'validUntil': null},
        },
      ],
    });
    final curb = map.curbs.single;
    expect(curb.status, ParkingStatus.allowed);
    expect(curb.lines.single.first.latitude, 45.50);
    expect(curb.lines.single.first.longitude, -73.56);
  });
}
