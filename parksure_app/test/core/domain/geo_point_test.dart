import 'package:flutter_test/flutter_test.dart';
import 'package:parksure_app/core/domain/geo_point.dart';

void main() {
  test('two points with the same coordinates are equal', () {
    expect(const GeoPoint(45.5, -73.6), const GeoPoint(45.5, -73.6));
    expect(const GeoPoint(45.5, -73.6), isNot(const GeoPoint(45.5, -73.7)));
  });

  test('rejects coordinates out of range', () {
    expect(() => GeoPoint(91, 0), throwsA(isA<AssertionError>()));
    expect(() => GeoPoint(0, 181), throwsA(isA<AssertionError>()));
  });
}
