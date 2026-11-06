/// A posted sign linked to a curb, e.g. "P-102 · No parking 8:00-11:00".
class CurbSign {
  const CurbSign({
    required this.signId,
    required this.code,
    required this.confidence,
    this.text,
  });

  final int signId;
  final String code;

  /// How sure the link between this sign and the curb is, from 0 to 1.
  final double confidence;
  final String? text;
}
