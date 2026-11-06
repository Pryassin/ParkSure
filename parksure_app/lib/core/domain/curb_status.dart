/// Whether you can park on a curb right now. Used by both the map and the
/// verdict sheet, so it lives in core.
enum CurbStatus { allowed, conditions, notAllowed, unknown }

/// Why the status is [CurbStatus.unknown].
enum UnknownReason { noCurb, noDataArea, noSigns, lowConfidence, noRule, other }
