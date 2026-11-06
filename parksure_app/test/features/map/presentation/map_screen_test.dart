import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parksure_app/core/api/parksure_api.dart';
import 'package:parksure_app/features/map/presentation/curb_lines_layer.dart';
import 'package:parksure_app/features/map/presentation/map_screen.dart';

Map<String, Object?> _feature(int id, String status) => {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-73.5812, 45.5235],
          [-73.5805, 45.5238],
        ],
      },
      'properties': {
        'segmentId': id,
        'side': 'Gauche',
        'status': status,
        'reason': '',
        'validUntil': null,
      },
    };

Future<void> _pumpScreen(WidgetTester tester, Future<http.Response> Function() respond) async {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone-sized, 3×
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final api = ParkSureApi(
    baseUrl: Uri.parse('http://test'),
    client: MockClient((_) => respond()),
  );
  await tester.pumpWidget(MaterialApp(home: MapScreen(api: api, showBaseMap: false)));
  // testWidgets runs on a fake clock: advance it past the debounce, then let
  // the real async work (HTTP + background isolate parse) finish.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pump();
}

void main() {
  testWidgets('shows the curbs and the legend counts', (tester) async {
    await _pumpScreen(
      tester,
      () async => http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'evaluatedAt': '2026-11-11T10:00:00-05:00',
            'truncated': false,
            'features': [
              _feature(1, 'allowed'),
              _feature(2, 'not_allowed'),
              _feature(3, 'not_allowed'),
              _feature(4, 'unknown'),
            ],
          }),
          200),
    );

    expect(find.text('ParkSure'), findsOneWidget);
    expect(find.text('Tap a curb to check it'), findsOneWidget);
    expect(find.byType(CurbLinesLayer), findsOneWidget);
    expect(find.bySemanticsLabel('1 allowed'), findsOneWidget);
    expect(find.bySemanticsLabel('0 with conditions'), findsOneWidget);
    expect(find.bySemanticsLabel('2 not allowed'), findsOneWidget);
    expect(find.bySemanticsLabel('1 unknown'), findsOneWidget);
  });

  testWidgets('offline shows the banner with Retry', (tester) async {
    await _pumpScreen(tester, () async => throw http.ClientException('Connection refused'));

    expect(find.textContaining("Can't reach ParkSure."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CurbLinesLayer), findsNothing);
  });
}
