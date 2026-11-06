/// A latitude/longitude pair. Plain Dart, so the domain does not depend on a
/// map package.
class GeoPoint {
  const GeoPoint(this.lat, this.lon)
      : assert(lat >= -90 && lat <= 90, 'lat out of range'),
        assert(lon >= -180 && lon <= 180, 'lon out of range');

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}
