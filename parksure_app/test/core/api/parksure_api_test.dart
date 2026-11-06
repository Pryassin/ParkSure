import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parksure_app/core/api/api_exception.dart';
import 'package:parksure_app/core/api/parksure_api.dart';
import 'package:parksure_app/core/domain/curb_status.dart';
import 'package:parksure_app/core/domain/geo_bounds.dart';
import 'package:parksure_app/core/domain/geo_point.dart';
import 'package:parksure_app/features/verdict/domain/curb_answer.dart';

// Shapes copied from real responses of the local API.

const _mapJson = {
  'type': 'FeatureCollection',
  'evaluatedAt': '2026-11-11T10:00:00-05:00',
  'truncated': false,
  'features': [
    {
      'type': 'Feature',
      'id': 10503,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-73.577312, 45.522783],
          [-73.57962, 45.523838],
        ],
      },
      'properties': {
        'segmentId': 10503,
        'side': 'Gauche',
        'status': 'not_allowed',
        'reason': 'No stopping (AD-TT)',
        'validUntil': null,
      },
    },
    {
      'type': 'Feature',
      'id': 12571,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-73.57, 45.504],
          [-73.571, 45.505],
        ],
      },
      'properties': {
        'segmentId': 12571,
        'side': 'Droite',
        'status': 'allowed',
        'reason': 'No restriction active now',
        'validUntil': '2026-11-12T06:30:00-05:00',
      },
    },
  ],
};

const _verdictJson = {
  'outcome': 'evaluated',
  'status': 'allowed',
  'reason': 'No restriction active now',
  'unknownReason': null,
  'decidingCode': null,
  'validUntil': '2026-11-12T06:30:00-05:00',
  'paymentRequired': false,
  'maxMinutes': null,
  'activeCodes': <String>[],
  'curb': {
    'segmentId': 12571,
    'side': 'Gauche',
    'streetName': 'De Bleury',
    'borough': 'MTL',
    'distanceM': 0,
  },
  'signs': [
    {
      'signId': 196671,
      'code': 'AV-DC',
      'text': r'\A 06h30-09h30 LUN. AU VEN.',
      'confidence': 0.9444485192,
    },
  ],
  'disclaimer': 'Permitted does not mean a free spot. Always check the posted signs.',
};

const _ambiguousJson = {
  'outcome': 'ambiguous',
  'curbs': [
    {'segmentId': 1, 'side': 'Gauche', 'streetName': 'Rivard', 'borough': 'MTL', 'distanceM': 7.2},
    {'segmentId': 2, 'side': 'Droite', 'streetName': 'Rivard', 'borough': 'MTL', 'distanceM': 8.1},
  ],
};

/// An API backed by a fake client. [onRequest] sees every request.
ParkSureApi _api(
  int status,
  Object body, {
  void Function(http.Request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return ParkSureApi(client: client, baseUrl: Uri.parse('http://test:5277'));
}

const _bounds = GeoBounds(minLon: -73.585, minLat: 45.521, maxLon: -73.578, maxLat: 45.526);
const _point = GeoPoint(45.5236, -73.5810);

void main() {
  group('getMap', () {
    test('sends bbox in minLon,minLat,maxLon,maxLat order and a UTC time', () async {
      late Uri sent;
      final api = _api(200, _mapJson, onRequest: (r) => sent = r.url);

      await api.getMap(_bounds, at: DateTime.utc(2026, 11, 11, 15), permit: '  ');

      expect(sent.path, '/api/curbs');
      expect(sent.queryParameters['bbox'], '-73.585,45.521,-73.578,45.526');
      expect(sent.queryParameters['at'], '2026-11-11T15:00:00.000Z');
      expect(sent.queryParameters.containsKey('permit'), isFalse, reason: 'blank permit is not sent');
    });

    test('reads segments, flipping GeoJSON [lon, lat] into GeoPoint(lat, lon)', () async {
      final map = await _api(200, _mapJson).getMap(_bounds);

      expect(map.segments, hasLength(2));
      expect(map.isTruncated, isFalse);
      final first = map.segments.first;
      expect(first.segmentId, 10503);
      expect(first.status, CurbStatus.notAllowed);
      expect(first.points.first, const GeoPoint(45.522783, -73.577312));
      expect(first.validUntil, isNull);
      expect(map.segments.last.validUntil, DateTime.utc(2026, 11, 12, 11, 30));
      expect(map.countByStatus[CurbStatus.allowed], 1);
    });

    test('an unrecognised status is shown as unknown, never as a guess', () async {
      final json = jsonDecode(jsonEncode(_mapJson)) as Map<String, dynamic>;
      json['features'][1]['properties']['status'] = 'some_new_status';

      final map = await _api(200, json).getMap(_bounds);

      expect(map.segments.last.status, CurbStatus.unknown);
    });

    test('skips a feature with geometry it cannot draw', () async {
      final json = jsonDecode(jsonEncode(_mapJson)) as Map<String, dynamic>;
      json['features'][0]['geometry'] = {'type': 'Point', 'coordinates': [-73.5, 45.5]};

      final map = await _api(200, json).getMap(_bounds);

      expect(map.segments.map((s) => s.segmentId), [12571]);
    });

    test('"bbox is too large" becomes tooLarge so the map can say "zoom in"', () async {
      final api = _api(400, {'error': 'bbox is too large, zoom in'});

      await expectLater(
        api.getMap(_bounds),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.tooLarge)
            .having((e) => e.message, 'message', 'bbox is too large, zoom in')),
      );
    });
  });

  group('getAnswer', () {
    test('sends point, mode, segmentId and permit', () async {
      late Uri sent;
      final api = _api(200, _verdictJson, onRequest: (r) => sent = r.url);

      await api.getAnswer(_point, mode: PinMode.tap, segmentId: 12571, permit: ' 198 ');

      expect(sent.path, '/api/curbs/at');
      expect(sent.queryParameters, {
        'lat': '45.5236',
        'lon': '-73.581',
        'mode': 'tap',
        'segmentId': '12571',
        'permit': '198',
      });
    });

    test('reads an evaluated answer into a Verdict', () async {
      final answer = await _api(200, _verdictJson).getAnswer(_point);

      expect(answer, isA<Verdict>());
      final verdict = answer as Verdict;
      expect(verdict.status, CurbStatus.allowed);
      expect(verdict.validUntil, DateTime.utc(2026, 11, 12, 11, 30));
      expect(verdict.curb?.streetName, 'De Bleury');
      expect(verdict.curb?.distanceMeters, 0.0);
      expect(verdict.signs.single.code, 'AV-DC');
      expect(verdict.disclaimer, contains('Always check the posted signs'));
    });

    test('reads the unknown reason', () async {
      final json = {
        ..._verdictJson,
        'status': 'unknown',
        'unknownReason': 'no_rule',
        'validUntil': null,
      };

      final verdict = await _api(200, json).getAnswer(_point) as Verdict;

      expect(verdict.status, CurbStatus.unknown);
      expect(verdict.unknownReason, UnknownReason.noRule);
    });

    test('an ambiguous tap becomes PickSide with both curbs', () async {
      final answer = await _api(200, _ambiguousJson).getAnswer(_point, mode: PinMode.tap);

      expect(answer, isA<PickSide>());
      final choices = (answer as PickSide).choices;
      expect(choices.map((c) => c.segmentId), [1, 2]);
      expect(choices.first.distanceMeters, 7.2);
    });

    test('unknown segment becomes notFound', () async {
      final api = _api(404, {'error': 'unknown segment'});

      await expectLater(
        api.getAnswer(_point, segmentId: 99999999),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.notFound)),
      );
    });
  });

  group('errors', () {
    test('a validation error keeps the API message', () async {
      final api = _api(400, {'error': 'mode must be gps or tap'});

      await expectLater(
        api.getAnswer(_point),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.badRequest)
            .having((e) => e.message, 'message', 'mode must be gps or tap')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('a 500 without JSON is a server error', () async {
      await expectLater(
        _api(500, 'boom').getMap(_bounds),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.server)
            .having((e) => e.message, 'message', 'HTTP 500')),
      );
    });

    test('a 200 with the wrong shape is a server error, not a crash', () async {
      await expectLater(
        _api(200, {'features': 'nope'}).getMap(_bounds),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server)),
      );
    });

    test('no connection is a network error', () async {
      final api = ParkSureApi(
        client: MockClient((_) async => throw http.ClientException('Connection refused')),
        baseUrl: Uri.parse('http://test:5277'),
      );

      await expectLater(
        api.getMap(_bounds),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)),
      );
    });

    test('a slow server is a network error', () async {
      final api = ParkSureApi(
        client: MockClient((_) => Future.delayed(
              const Duration(seconds: 1),
              () => http.Response('{}', 200),
            )),
        baseUrl: Uri.parse('http://test:5277'),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        api.getMap(_bounds),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)),
      );
    });
  });
}
