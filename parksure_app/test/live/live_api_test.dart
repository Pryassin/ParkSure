// Calls the real local API. Skipped unless enabled:
//
//   PARKSURE_LIVE_API=http://localhost:5277 flutter test test/live
//
// Needs the backend running (see the root README, "Running the API").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parksure_app/core/api/api_exception.dart';
import 'package:parksure_app/core/api/parksure_api.dart';
import 'package:parksure_app/core/domain/curb_status.dart';
import 'package:parksure_app/core/domain/geo_bounds.dart';
import 'package:parksure_app/core/domain/geo_point.dart';
import 'package:parksure_app/features/verdict/domain/curb_answer.dart';

void main() {
  final base = Platform.environment['PARKSURE_LIVE_API'];
  final skip = base == null ? 'set PARKSURE_LIVE_API to run' : false;
  late ParkSureApi api;

  setUpAll(() => api = ParkSureApi(baseUrl: Uri.parse(base ?? 'http://unused')));
  tearDownAll(() => api.close());

  // Plateau-Mont-Royal, a Wednesday morning.
  const plateau = GeoBounds(minLon: -73.585, minLat: 45.521, maxLon: -73.578, maxLat: 45.526);
  final wednesday10am = DateTime.utc(2026, 11, 11, 15);

  test('map: Plateau returns drawable curbs of every kind', () async {
    final map = await api.getMap(plateau, at: wednesday10am);

    expect(map.segments, isNotEmpty);
    expect(map.segments.every((s) => s.points.length >= 2), isTrue);
    expect(map.countByStatus[CurbStatus.notAllowed], greaterThan(0));
    // ignore: avoid_print
    print('Plateau: ${map.segments.length} curbs ${map.countByStatus}');
  }, skip: skip);

  test('map: a huge area asks the user to zoom in', () async {
    const island = GeoBounds(minLon: -74, minLat: 45, maxLon: -73, maxLat: 46);
    await expectLater(
      api.getMap(island),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.tooLarge)),
    );
  }, skip: skip);

  test('answer: De Bleury at 14:00 is allowed until 06:30', () async {
    final answer = await api.getAnswer(
      const GeoPoint(45.5040, -73.5700),
      mode: PinMode.tap,
      segmentId: 12571,
      at: DateTime.utc(2026, 11, 11, 19),
    );

    final verdict = answer as Verdict;
    expect(verdict.status, CurbStatus.allowed);
    expect(verdict.curb?.streetName, 'De Bleury');
    expect(verdict.validUntil, DateTime.utc(2026, 11, 12, 11, 30));
  }, skip: skip);

  test('answer: Rivard is unknown because a sign has no rule yet', () async {
    final verdict = await api.getAnswer(const GeoPoint(45.5236, -73.5810)) as Verdict;

    expect(verdict.status, CurbStatus.unknown);
    expect(verdict.unknownReason, UnknownReason.noRule);
    expect(verdict.signs, isNotEmpty);
  }, skip: skip);
}
