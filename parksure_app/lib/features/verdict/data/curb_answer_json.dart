import '../../../core/api/json_parsing.dart';
import '../domain/curb_answer.dart';
import '../domain/curb_side.dart';
import '../domain/curb_sign.dart';

/// Reads the response from `GET /api/curbs/at`.
///
/// * `"outcome": "ambiguous"` → [PickSide] (the tap was between two curbs)
/// * `"outcome": "evaluated"` → [Verdict]
CurbAnswer curbAnswerFromJson(Map<String, dynamic> json) {
  if (json['outcome'] == 'ambiguous') {
    return PickSide([
      for (final c in (json['curbs'] as List).cast<Map<String, dynamic>>())
        curbSideFromJson(c),
    ]);
  }

  final curb = json['curb'] as Map<String, dynamic>?;
  return Verdict(
    status: parseStatus(json['status']),
    reason: json['reason'] as String? ?? '',
    disclaimer: json['disclaimer'] as String? ?? '',
    unknownReason: parseUnknownReason(json['unknownReason']),
    decidingCode: json['decidingCode'] as String?,
    validUntil: parseTime(json['validUntil']),
    paymentRequired: json['paymentRequired'] as bool? ?? false,
    maxMinutes: json['maxMinutes'] as int?,
    activeCodes: (json['activeCodes'] as List? ?? const []).cast<String>(),
    curb: curb == null ? null : curbSideFromJson(curb),
    signs: [
      for (final s in (json['signs'] as List? ?? const [])
          .cast<Map<String, dynamic>>())
        curbSignFromJson(s),
    ],
  );
}

CurbSide curbSideFromJson(Map<String, dynamic> json) => CurbSide(
      segmentId: json['segmentId'] as int,
      side: json['side'] as String,
      distanceMeters: toDouble(json['distanceM']),
      streetName: json['streetName'] as String?,
      borough: json['borough'] as String?,
    );

CurbSign curbSignFromJson(Map<String, dynamic> json) => CurbSign(
      signId: json['signId'] as int,
      code: json['code'] as String,
      confidence: toDouble(json['confidence']),
      text: json['text'] as String?,
    );
