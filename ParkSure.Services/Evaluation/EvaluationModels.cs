using System.Text.RegularExpressions;

namespace ParkSure.Evaluation;

public enum CurbStatus { Allowed, Conditions, NotAllowed, Unknown }

public enum UnknownReason { NoCurb, NoDataArea, NoSigns, LowConfidence, NoRule }

public enum RuleKind { NoStopping, NoParking, NoParkingExceptPermit, DurationLimit, PaidParking }

/// <summary>
/// One time window of a rule. Minutes are minutes since local midnight (America/Toronto).
/// Days: ISO 1=Monday..7=Sunday, null = every day. Months: 1..12, null = all year.
/// ToMinute earlier than FromMinute = overnight window (belongs to the day it STARTS on).
/// Start is inclusive, end is exclusive. An end of "23:59" is stored as 1440 (end of day).
/// </summary>
public sealed record RuleWindow(IReadOnlyList<int>? Days, int FromMinute, int ToMinute, IReadOnlyList<int>? Months)
{
    private static readonly Regex Hhmm = new(@"^([01][0-9]|2[0-3]):[0-5][0-9]$", RegexOptions.Compiled);

    public bool IsOvernight => ToMinute < FromMinute;

    /// <summary>Returns null when the window cannot be read. Nothing is ever guessed.</summary>
    public static RuleWindow? TryCreate(IReadOnlyList<int>? days, string? from, string? to, IReadOnlyList<int>? months)
    {
        if (from is null || to is null || !Hhmm.IsMatch(from) || !Hhmm.IsMatch(to) || from == to) return null;
        if (days is not null && (days.Count == 0 || days.Any(d => d < 1 || d > 7))) return null;
        if (months is not null && (months.Count == 0 || months.Any(m => m < 1 || m > 12))) return null;
        int f = ToMinutes(from);
        int t = to == "23:59" ? 1440 : ToMinutes(to);
        return new RuleWindow(days, f, t, months);
    }

    private static int ToMinutes(string hhmm) => int.Parse(hhmm[..2]) * 60 + int.Parse(hhmm[3..]);
}

/// <summary>A rule that is reviewed, readable and of a recognised type. Empty Windows = always active.</summary>
public sealed record ParkingRule(
    string Code,
    RuleKind Kind,
    int Priority,
    IReadOnlyList<RuleWindow> Windows,
    string? PermitSector = null,
    int? MaxMinutes = null);

/// <summary>A sign linked to the curb side. Rule = null means "no usable rule" (missing, unreviewed, unreadable or unrecognised).</summary>
public sealed record LinkedSign(int SignId, string Code, decimal Confidence, ParkingRule? Rule, string? Arrow = null);

public sealed record CurbContext(bool CurbFound, bool InCoveredArea, IReadOnlyList<LinkedSign> Signs);

public sealed record EvaluationResult(
    CurbStatus Status,
    UnknownReason? UnknownReason,
    string Reason,
    string? DecidingCode,
    DateTimeOffset? ValidUntil,
    bool PaymentRequired,
    int? MaxMinutes,
    IReadOnlyList<string> ActiveCodes,
    IReadOnlyList<string> MissingCodes);
