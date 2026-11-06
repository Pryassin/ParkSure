/// A curb near the tapped point, e.g. "Rue Rivard · right side, 24.8 m".
class CurbSide {
  const CurbSide({
    required this.segmentId,
    required this.side,
    required this.distanceMeters,
    this.streetName,
    this.borough,
  });

  final int segmentId;
  final String side;
  final double distanceMeters;
  final String? streetName;
  final String? borough;
}
