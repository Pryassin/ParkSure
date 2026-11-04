/// The four answers the API can give. Mirrors the backend `status` strings.
enum ParkingStatus {
  allowed,
  conditions,
  notAllowed,
  unknown;

  /// Anything we don't recognise is treated as unknown — never as green.
  static ParkingStatus fromApi(String? value) => switch (value) {
        'allowed' => ParkingStatus.allowed,
        'conditions' => ParkingStatus.conditions,
        'not_allowed' => ParkingStatus.notAllowed,
        _ => ParkingStatus.unknown,
      };
}

/// One sign linked to the curb side.
class Sign {
  const Sign({required this.signId, required this.code, this.text, required this.confidence});

  final int signId;
  final String code;
  final String? text;
  final double confidence;

  factory Sign.fromJson(Map<String, dynamic> json) => Sign(
        signId: json['signId'] as int,
        code: json['code'] as String,
        text: json['text'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
      );
}

/// A curb side candidate, as returned by `/api/curbs/at` (`curb` or `curbs[]`).
class CurbCandidate {
  const CurbCandidate({
    required this.segmentId,
    required this.side,
    this.streetName,
    this.borough,
    required this.distanceM,
  });

  final int segmentId;
  final String side;
  final String? streetName;
  final String? borough;
  final double distanceM;

  factory CurbCandidate.fromJson(Map<String, dynamic> json) => CurbCandidate(
        segmentId: json['segmentId'] as int,
        side: json['side'] as String,
        streetName: json['streetName'] as String?,
        borough: json['borough'] as String?,
        distanceM: (json['distanceM'] as num).toDouble(),
      );
}

/// The answer from `GET /api/curbs/at`.
///
/// Either [isAmbiguous] (the user must pick a side from [candidates]) or a full
/// evaluation with a [status].
class Verdict {
  const Verdict({
    required this.outcome,
    this.status = ParkingStatus.unknown,
    this.reason,
    this.unknownReason,
    this.decidingCode,
    this.validUntil,
    this.paymentRequired = false,
    this.maxMinutes,
    this.activeCodes = const [],
    this.curb,
    this.candidates = const [],
    this.signs = const [],
    this.disclaimer,
  });

  final String outcome; // "evaluated" | "ambiguous"
  final ParkingStatus status;
  final String? reason;
  final String? unknownReason;
  final String? decidingCode;
  final DateTime? validUntil;
  final bool paymentRequired;
  final int? maxMinutes;
  final List<String> activeCodes;
  final CurbCandidate? curb;
  final List<CurbCandidate> candidates;
  final List<Sign> signs;
  final String? disclaimer;

  bool get isAmbiguous => outcome == 'ambiguous';

  factory Verdict.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>().map(f).toList();

    return Verdict(
      outcome: json['outcome'] as String,
      status: ParkingStatus.fromApi(json['status'] as String?),
      reason: json['reason'] as String?,
      unknownReason: json['unknownReason'] as String?,
      decidingCode: json['decidingCode'] as String?,
      validUntil: json['validUntil'] == null ? null : DateTime.parse(json['validUntil'] as String),
      paymentRequired: json['paymentRequired'] as bool? ?? false,
      maxMinutes: json['maxMinutes'] as int?,
      activeCodes: ((json['activeCodes'] as List?) ?? const []).cast<String>(),
      curb: json['curb'] == null ? null : CurbCandidate.fromJson(json['curb'] as Map<String, dynamic>),
      candidates: list('curbs', CurbCandidate.fromJson),
      signs: list('signs', Sign.fromJson),
      disclaimer: json['disclaimer'] as String?,
    );
  }
}
