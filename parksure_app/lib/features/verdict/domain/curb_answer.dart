import '../../../core/domain/curb_status.dart';
import 'curb_side.dart';
import 'curb_sign.dart';

/// What the app gets back after checking a point.
///
/// `sealed` means these are the only two cases, so a `switch` on a
/// [CurbAnswer] must handle both, or it will not compile:
///
///   switch (answer) {
///     Verdict v  => VerdictSheet(v),
///     PickSide p => WhichSideSheet(p.choices),
///   }
sealed class CurbAnswer {
  const CurbAnswer();
}

/// The tap was between two curbs: the user must pick one ("Which side?").
class PickSide extends CurbAnswer {
  const PickSide(this.choices);

  final List<CurbSide> choices;
}

/// The answer for one curb: Allowed / Not allowed / Conditions / Unknown.
class Verdict extends CurbAnswer {
  const Verdict({
    required this.status,
    required this.reason,
    required this.disclaimer,
    this.unknownReason,
    this.decidingCode,
    this.validUntil,
    this.paymentRequired = false,
    this.maxMinutes,
    this.activeCodes = const [],
    this.curb,
    this.signs = const [],
  });

  final CurbStatus status;
  final String reason;
  final String disclaimer;

  /// Only set when [status] is [CurbStatus.unknown].
  final UnknownReason? unknownReason;

  /// The sign code that decided the status, e.g. "SD-TT".
  final String? decidingCode;
  final DateTime? validUntil;
  final bool paymentRequired;

  /// Time limit in minutes, e.g. 60 for "60 min limit".
  final int? maxMinutes;
  final List<String> activeCodes;
  final CurbSide? curb;
  final List<CurbSign> signs;

  /// Time until [status] changes ("in 25 min"). Null if there is no end time,
  /// zero if it has already passed.
  Duration? timeLeft(DateTime now) {
    final until = validUntil;
    if (until == null) return null;
    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}
