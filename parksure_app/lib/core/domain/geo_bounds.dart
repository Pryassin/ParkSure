/// The visible map rectangle, sent to the API as
/// `bbox=minLon,minLat,maxLon,maxLat`.
class GeoBounds {
  const GeoBounds({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  })  : assert(minLon < maxLon, 'minLon must be smaller than maxLon'),
        assert(minLat < maxLat, 'minLat must be smaller than maxLat');

  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  /// The order the API expects.
  String toQuery() => '$minLon,$minLat,$maxLon,$maxLat';

  @override
  String toString() => 'GeoBounds(${toQuery()})';
}
