import '../domain/curb_status.dart';

/// Shared helpers for turning API JSON into domain values.
///
/// Safety rule: anything the app does not recognise becomes
/// [CurbStatus.unknown], never a guess. A new status added to the API must
/// not turn into a false green in an old app.

CurbStatus parseStatus(Object? value) => switch (value) {
      'allowed' => CurbStatus.allowed,
      'conditions' => CurbStatus.conditions,
      'not_allowed' => CurbStatus.notAllowed,
      _ => CurbStatus.unknown,
    };

UnknownReason? parseUnknownReason(Object? value) => switch (value) {
      null => null,
      'no_curb' => UnknownReason.noCurb,
      'no_data_area' => UnknownReason.noDataArea,
      'no_signs' => UnknownReason.noSigns,
      'low_confidence' => UnknownReason.lowConfidence,
      'no_rule' => UnknownReason.noRule,
      _ => UnknownReason.other,
    };

/// Parses an ISO 8601 time with an offset (e.g. `2026-11-12T06:30:00-05:00`).
/// The result is in UTC; call `.toLocal()` to display it.
DateTime? parseTime(Object? value) =>
    value is String ? DateTime.parse(value) : null;

double toDouble(Object? value) => (value as num).toDouble();
