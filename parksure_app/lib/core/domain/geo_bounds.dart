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

  double get widthLon => maxLon - minLon;
  double get heightLat => maxLat - minLat;

  /// True when [other] lies completely inside this box.
  bool containsBounds(GeoBounds other) =>
      other.minLon >= minLon &&
      other.maxLon <= maxLon &&
      other.minLat >= minLat &&
      other.maxLat <= maxLat;

  /// This box grown by [factor] of its size on every side (0.5 → twice as
  /// wide and tall), then shrunk around its centre if needed so it is never
  /// larger than [maxWidthLon] × [maxHeightLat].
  GeoBounds expanded(
    double factor, {
    double maxWidthLon = double.infinity,
    double maxHeightLat = double.infinity,
  }) {
    final width = (widthLon * (1 + 2 * factor)).clamp(0.0, maxWidthLon);
    final height = (heightLat * (1 + 2 * factor)).clamp(0.0, maxHeightLat);
    final centerLon = (minLon + maxLon) / 2;
    final centerLat = (minLat + maxLat) / 2;
    return GeoBounds(
      minLon: centerLon - width / 2,
      minLat: centerLat - height / 2,
      maxLon: centerLon + width / 2,
      maxLat: centerLat + height / 2,
    );
  }

  /// The order the API expects.
  String toQuery() => '$minLon,$minLat,$maxLon,$maxLat';

  @override
  String toString() => 'GeoBounds(${toQuery()})';
}
