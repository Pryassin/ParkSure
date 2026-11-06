import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parksure_app/core/api/parksure_api.dart';
import 'package:parksure_app/core/domain/curb_status.dart';
import 'package:parksure_app/core/domain/geo_bounds.dart';
import 'package:parksure_app/features/map/presentation/curb_map_controller.dart';

/// A feature at [lon], [lat] with [status].
Map<String, Object?> _feature(int id, double lon, double lat, String status, {String? until}) => {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [lon, lat],
          [lon + 0.0005, lat],
        ],
      },
      'properties': {
        'segmentId': id,
        'side': 'Gauche',
        'status': status,
        'reason': '',
        'validUntil': until,
      },
    };

String _body(List<Map<String, Object?>> features) => jsonEncode({
      'type': 'FeatureCollection',
      'evaluatedAt': '2026-11-11T10:00:00-05:00',
      'truncated': false,
      'features': features,
    });

/// Screen-sized box (about 0.008 × 0.006, a phone at zoom 17).
GeoBounds _screen(double lon, double lat) =>
    GeoBounds(minLon: lon, minLat: lat, maxLon: lon + 0.008, maxLat: lat + 0.006);

const _zoom = 17.0;
// Generous: parsing runs on a background isolate, slower to start under load.
const _wait = Duration(milliseconds: 250);

class _FakeServer {
  final requests = <Uri>[];
  Future<http.Response> Function(Uri url) respond =
      (_) async => http.Response(_body([_feature(1, -73.58, 45.523, 'allowed')]), 200);

  ParkSureApi api() => ParkSureApi(
        baseUrl: Uri.parse('http://test'),
        client: MockClient((request) {
          requests.add(request.url);
          return respond(request.url);
        }),
      );
}

void main() {
  late _FakeServer server;
  late CurbMapController controller;

  setUp(() {
    server = _FakeServer();
    controller = CurbMapController(api: server.api(), debounce: const Duration(milliseconds: 10));
  });
  tearDown(() => controller.dispose());

  test('loads the screen plus half a screen of margin on every side', () async {
    controller.onViewportChanged(_screen(-73.585, 45.521), _zoom);
    await Future<void>.delayed(_wait);

    expect(server.requests, hasLength(1));
    final bbox = server.requests.single.queryParameters['bbox']!.split(',').map(double.parse).toList();
    expect(bbox[2] - bbox[0], closeTo(0.016, 1e-9), reason: '2× the screen width');
    expect(bbox[3] - bbox[1], closeTo(0.012, 1e-9), reason: '2× the screen height');
    expect(controller.curbMap?.segments, hasLength(1));
    expect(controller.isLoading, isFalse);
    expect(controller.problem, isNull);
  });

  test('a small pan inside the loaded area sends no request', () async {
    controller.onViewportChanged(_screen(-73.585, 45.521), _zoom);
    await Future<void>.delayed(_wait);

    controller.onViewportChanged(_screen(-73.583, 45.522), _zoom); // ¼ screen
    await Future<void>.delayed(_wait);

    expect(server.requests, hasLength(1));
  });

  test('a fling sends one request where it stops, not one per frame', () async {
    for (var i = 0; i < 30; i++) {
      controller.onViewportChanged(_screen(-73.60 + i * 0.002, 45.52), _zoom);
    }
    await Future<void>.delayed(_wait);

    expect(server.requests, hasLength(1));
    final minLon = double.parse(server.requests.single.queryParameters['bbox']!.split(',').first);
    expect(minLon, closeTo(-73.60 + 29 * 0.002 - 0.004, 1e-9), reason: 'around the last position');
  });

  test('a slow answer for an old position never replaces a newer one', () async {
    final slow = Completer<http.Response>();
    server.respond = (url) => server.requests.length == 1
        ? slow.future
        : Future.value(http.Response(_body([_feature(2, -73.50, 45.52, 'not_allowed')]), 200));

    controller.onViewportChanged(_screen(-73.585, 45.521), _zoom);
    await Future<void>.delayed(_wait); // request 1 in flight
    controller.onViewportChanged(_screen(-73.505, 45.521), _zoom); // far away
    await Future<void>.delayed(_wait); // request 2 answered

    slow.complete(http.Response(_body([_feature(1, -73.58, 45.523, 'allowed')]), 200));
    await Future<void>.delayed(_wait);

    expect(controller.curbMap?.segments.single.segmentId, 2);
  });

  test('zoomed out: asks to zoom in, hides curbs, sends nothing', () async {
    controller.onViewportChanged(_screen(-73.585, 45.521), 14);
    await Future<void>.delayed(_wait);

    expect(controller.problem, MapProblem.zoomIn);
    expect(controller.showsCurbs, isFalse);
    expect(server.requests, isEmpty);
  });

  test('a screen larger than the API allows also asks to zoom in', () async {
    const huge = GeoBounds(minLon: -73.70, minLat: 45.45, maxLon: -73.55, maxLat: 45.55);
    controller.onViewportChanged(huge, 16);
    await Future<void>.delayed(_wait);

    expect(controller.problem, MapProblem.zoomIn);
    expect(server.requests, isEmpty);
  });

  test('the request never exceeds the API limit, even with the margin', () async {
    // 0.05 wide: inside the limit, but 2× would be 0.10.
    const wide = GeoBounds(minLon: -73.62, minLat: 45.50, maxLon: -73.57, maxLat: 45.53);
    controller.onViewportChanged(wide, 15);
    await Future<void>.delayed(_wait);

    final bbox = server.requests.single.queryParameters['bbox']!.split(',').map(double.parse).toList();
    expect(bbox[2] - bbox[0], lessThanOrEqualTo(CurbMapController.maxSpanLon + 1e-9));
    expect(bbox[3] - bbox[1], lessThanOrEqualTo(CurbMapController.maxSpanLat + 1e-9));
  });

  test('offline keeps the last curbs on screen; Retry reloads', () async {
    controller.onViewportChanged(_screen(-73.585, 45.521), _zoom);
    await Future<void>.delayed(_wait);

    server.respond = (_) async => throw http.ClientException('Connection refused');
    await controller.refresh();

    expect(controller.problem, MapProblem.offline);
    expect(controller.curbMap?.segments, hasLength(1), reason: 'old curbs still shown');
    expect(controller.showsCurbs, isTrue);

    server.respond = (_) async => http.Response(_body([]), 200);
    await controller.refresh();

    expect(controller.problem, isNull);
    expect(controller.curbMap?.segments, isEmpty);
  });

  test('the legend counts only curbs on screen, not the prefetched margin', () async {
    server.respond = (_) async => http.Response(
        _body([
          _feature(1, -73.584, 45.522, 'allowed'), // on screen
          _feature(2, -73.583, 45.523, 'not_allowed'), // on screen
          _feature(3, -73.590, 45.518, 'not_allowed'), // margin only
        ]),
        200);

    controller.onViewportChanged(_screen(-73.585, 45.521), _zoom);
    await Future<void>.delayed(_wait);

    expect(controller.visibleCounts, {
      CurbStatus.allowed: 1,
      CurbStatus.conditions: 0,
      CurbStatus.notAllowed: 1,
      CurbStatus.unknown: 0,
    });
  });

  test('reloads by itself when a curb on screen changes status', () async {
    final now = DateTime.utc(2026, 11, 11, 14, 59, 59, 900);
    final soon = now.add(const Duration(milliseconds: 50)).toIso8601String();
    controller.dispose();
    controller = CurbMapController(
      api: server.api(),
      debounce: const Duration(milliseconds: 10),
      clock: () => now,
    );
    server.respond = (_) async =>
        http.Response(_body([_feature(1, -73.584, 45.522, 'allowed', until: soon)]), 200);

    controller.onViewportChanged(_screen(-73.585, 45.521), _zoom);
    await Future<void>.delayed(_wait);
    expect(server.requests, hasLength(1));

    // validUntil + the 1 s safety margin.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(server.requests, hasLength(2));
  });

  group('GeoBounds.expanded', () {
    test('grows by the factor on each side, around the same centre', () {
      final b = _screen(-73.585, 45.521).expanded(0.5);
      expect(b.widthLon, closeTo(0.016, 1e-9));
      expect((b.minLon + b.maxLon) / 2, closeTo(-73.581, 1e-9));
    });

    test('is capped at the max size', () {
      final b = _screen(-73.585, 45.521).expanded(10, maxWidthLon: 0.01, maxHeightLat: 0.01);
      expect(b.widthLon, closeTo(0.01, 1e-9));
      expect(b.heightLat, closeTo(0.01, 1e-9));
    });
  });
}
