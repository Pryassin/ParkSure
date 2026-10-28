using System.Text;
using System.Text.RegularExpressions;

namespace ParkSure.Evaluation;

/// <summary>
/// Pieces 3 to 5 of the evaluator. Pure logic: no database, no clock, no network.
/// All wall-clock reasoning happens in America/Toronto.
/// </summary>
public sealed class CurbEvaluator
{
    public const decimal MinConfidence = 0.6m;                                   // below this = unknown
    public static readonly TimeSpan WarningWindow = TimeSpan.FromMinutes(60);    // "ban starts within 60 minutes" (inclusive)
    private static readonly int[] HorizonDays = { 2, 8, 32, 100, 366 };          // valid_until search, widened step by step

    private readonly TimeZoneInfo _tz;

    public CurbEvaluator() : this(FindToronto()) { }
    public CurbEvaluator(TimeZoneInfo tz) => _tz = tz;

    public static TimeZoneInfo FindToronto()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("America/Toronto"); }
        catch (TimeZoneNotFoundException) { return TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time"); }
    }

    // ---------------------------------------------------------------- evaluate

    public EvaluationResult Evaluate(CurbContext curb, DateTimeOffset at, string? userPermit)
    {
        // Pieces 1 and 2 outcomes, then piece 3 safety checks, in the locked order.
        if (!curb.CurbFound) return Unknown(UnknownReason.NoCurb, "No curb side found near this point");
        if (!curb.InCoveredArea) return Unknown(UnknownReason.NoDataArea, "No parking data for this area");
        if (curb.Signs.Count == 0) return Unknown(UnknownReason.NoSigns, "No signs are linked to this curb side");
        if (curb.Signs.Any(s => s.Confidence < MinConfidence))
            return Unknown(UnknownReason.LowConfidence, "A sign link is too uncertain to trust");

        var missing = curb.Signs.Where(s => s.Rule is null).Select(s => s.Code)
            .Distinct(StringComparer.Ordinal).OrderBy(c => c, StringComparer.Ordinal).ToList();
        if (missing.Count > 0)
            return Unknown(UnknownReason.NoRule, "A sign on this curb has no usable rule yet", missing);

        var rules = curb.Signs.Select(s => s.Rule!)
            .GroupBy(r => r.Code, StringComparer.Ordinal).Select(g => g.First())
            .OrderBy(r => r.Code, StringComparer.Ordinal).ToList();
        var permit = NormalizePermit(userPermit);

        // Pieces 4 and 5.
        var now = Classify(rules, at, permit);
        var status = now.Base;
        ParkingRule? deciding = null;
        string reason;

        if (status == CurbStatus.NotAllowed)
        {
            deciding = Ordered(now.Forbidding).First();
            reason = Describe(deciding);
        }
        else if (status == CurbStatus.Conditions)
        {
            deciding = Ordered(now.Conditions).First();
            reason = Describe(deciding);
        }
        else
        {
            var soon = UpcomingBans(rules, at, permit);
            if (soon.Count > 0)
            {
                var firstStart = soon.Min(b => b.Instant);
                deciding = Ordered(soon.Where(b => b.Instant == firstStart).Select(b => b.Rule)).First();
                status = CurbStatus.Conditions;
                reason = $"{Phrase(deciding)} starts at {Local(firstStart):HH:mm} ({deciding.Code})";
            }
            else if (now.Bypassed.Count > 0)
            {
                deciding = Ordered(now.Bypassed).First();
                reason = $"permit {permit} accepted";
            }
            else reason = "No restriction active now";
        }

        bool paymentRequired = false;
        int? maxMinutes = null;
        if (now.Base == CurbStatus.Conditions)
        {
            paymentRequired = now.Conditions.Any(c => c.Kind == RuleKind.PaidParking);
            var limits = now.Conditions.Where(c => c.MaxMinutes.HasValue).Select(c => c.MaxMinutes!.Value).ToList();
            if (limits.Count > 0) maxMinutes = limits.Min();
        }

        var active = now.Forbidding.Concat(now.Conditions).Concat(now.Bypassed)
            .Select(r => r.Code).OrderBy(c => c, StringComparer.Ordinal).ToList();

        return new EvaluationResult(status, null, reason, deciding?.Code,
            FindValidUntil(rules, at, permit, now.Base),
            paymentRequired, maxMinutes, active, Array.Empty<string>());
    }

    private static EvaluationResult Unknown(UnknownReason why, string text, IReadOnlyList<string>? missing = null) =>
        new(CurbStatus.Unknown, why, text, null, null, false, null, Array.Empty<string>(), missing ?? Array.Empty<string>());

    // ---------------------------------------------------------------- permit

    /// <summary>Lowercase, strip non-alphanumerics, strip leading zeros (in each run of digits).</summary>
    public static string NormalizePermit(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return "";
        var sb = new StringBuilder();
        foreach (var ch in raw.ToLowerInvariant())
            if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) sb.Append(ch);
        return Regex.Replace(sb.ToString(), @"\d+", m => m.Value.TrimStart('0'));
    }

    private static bool IsBypassed(ParkingRule rule, string permit)
    {
        if (rule.Kind != RuleKind.NoParkingExceptPermit || permit.Length == 0 || rule.PermitSector is null) return false;
        var sector = NormalizePermit(rule.PermitSector);
        return sector.Length > 0 && sector == permit;
    }

    private static bool IsBanKind(ParkingRule r) =>
        r.Kind is RuleKind.NoStopping or RuleKind.NoParking or RuleKind.NoParkingExceptPermit;

    // ---------------------------------------------------------------- classify (piece 4 + the base of piece 5)

    private sealed record Snapshot(CurbStatus Base, List<ParkingRule> Forbidding, List<ParkingRule> Conditions, List<ParkingRule> Bypassed);

    private Snapshot Classify(IReadOnlyList<ParkingRule> rules, DateTimeOffset at, string permit)
    {
        var local = Local(at);
        var forbidding = new List<ParkingRule>();
        var conditions = new List<ParkingRule>();
        var bypassed = new List<ParkingRule>();

        foreach (var rule in rules)
        {
            if (!IsActive(rule, local)) continue;
            switch (rule.Kind)
            {
                case RuleKind.NoStopping:
                case RuleKind.NoParking:
                    forbidding.Add(rule); break;
                case RuleKind.NoParkingExceptPermit:
                    if (IsBypassed(rule, permit)) bypassed.Add(rule); else forbidding.Add(rule);
                    break;
                case RuleKind.DurationLimit:
                case RuleKind.PaidParking:
                    conditions.Add(rule); break;
            }
        }

        var status = forbidding.Count > 0 ? CurbStatus.NotAllowed
                   : conditions.Count > 0 ? CurbStatus.Conditions
                   : CurbStatus.Allowed;
        return new Snapshot(status, forbidding, conditions, bypassed);
    }

    private static bool IsActive(ParkingRule rule, DateTime local)
    {
        if (rule.Windows.Count == 0) return true;      // [] = always active
        return rule.Windows.Any(w => WindowActive(w, local));
    }

    private static bool WindowActive(RuleWindow w, DateTime local)
    {
        int minute = local.Hour * 60 + local.Minute;
        var date = DateOnly.FromDateTime(local);

        if (!w.IsOvernight)
            return DayMonthMatch(w, date) && minute >= w.FromMinute && minute < w.ToMinute;

        // Overnight: the evening half belongs to today, the morning half to the day it started on (yesterday).
        if (minute >= w.FromMinute && DayMonthMatch(w, date)) return true;
        if (minute < w.ToMinute && DayMonthMatch(w, date.AddDays(-1))) return true;
        return false;
    }

    private static bool DayMonthMatch(RuleWindow w, DateOnly date)
    {
        int isoDay = date.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)date.DayOfWeek;
        if (w.Days is not null && !w.Days.Contains(isoDay)) return false;
        if (w.Months is not null && !w.Months.Contains(date.Month)) return false;
        return true;
    }

    // ---------------------------------------------------------------- boundaries, look-ahead, valid_until

    private sealed record Boundary(DateTimeOffset Instant, ParkingRule Rule, bool IsStart);

    private List<Boundary> Boundaries(IEnumerable<ParkingRule> rules, DateTimeOffset from, DateTimeOffset to)
    {
        var result = new List<Boundary>();
        var firstDay = Local(from).Date.AddDays(-1);
        var lastDay = Local(to).Date.AddDays(1);

        foreach (var rule in rules)
            foreach (var w in rule.Windows)
                for (var day = firstDay; day <= lastDay; day = day.AddDays(1))
                {
                    if (!DayMonthMatch(w, DateOnly.FromDateTime(day))) continue;
                    var start = ToInstant(day.AddMinutes(w.FromMinute));
                    var end = ToInstant(w.IsOvernight ? day.AddDays(1).AddMinutes(w.ToMinute) : day.AddMinutes(w.ToMinute));
                    if (start > from && start <= to) result.Add(new Boundary(start, rule, true));
                    if (end > from && end <= to) result.Add(new Boundary(end, rule, false));
                }
        return result;
    }

    private List<Boundary> UpcomingBans(IReadOnlyList<ParkingRule> rules, DateTimeOffset at, string permit) =>
        Boundaries(rules.Where(r => IsBanKind(r) && !IsBypassed(r, permit)), at, at + WarningWindow)
            .Where(b => b.IsStart).ToList();

    /// <summary>
    /// The first moment ahead when the base answer (not_allowed / conditions / allowed, ignoring the
    /// 60-minute warning) differs from now. Null when nothing changes within one year.
    /// </summary>
    private DateTimeOffset? FindValidUntil(IReadOnlyList<ParkingRule> rules, DateTimeOffset at, string permit, CurbStatus baseNow)
    {
        var checkedUntil = at;
        foreach (var days in HorizonDays)
        {
            var end = at.AddDays(days);
            var instants = Boundaries(rules, at, end).Select(b => b.Instant).Distinct().OrderBy(t => t);
            foreach (var t in instants)
            {
                if (t <= checkedUntil) continue;
                if (Classify(rules, t, permit).Base != baseNow) return t;
            }
            checkedUntil = end;
        }
        return null;
    }

    // ---------------------------------------------------------------- reasons

    private static int KindRank(RuleKind k) => k switch
    {
        RuleKind.NoStopping => 0,
        RuleKind.NoParking => 1,
        RuleKind.NoParkingExceptPermit => 2,
        RuleKind.DurationLimit => 3,
        _ => 4
    };

    /// <summary>Lowest priority number first; ties by stronger kind, then by code, so output is always identical.</summary>
    private static IOrderedEnumerable<ParkingRule> Ordered(IEnumerable<ParkingRule> rules) =>
        rules.OrderBy(r => r.Priority).ThenBy(r => KindRank(r.Kind)).ThenBy(r => r.Code, StringComparer.Ordinal);

    private static string Phrase(ParkingRule r) => r.Kind switch
    {
        RuleKind.NoStopping => "No stopping",
        RuleKind.NoParking => "No parking",
        RuleKind.NoParkingExceptPermit => "No parking except permit holders",
        RuleKind.DurationLimit => r.MaxMinutes is int limit ? $"Parking limited to {limit} min" : "Time-limited parking",
        RuleKind.PaidParking => r.MaxMinutes is int paidMax ? $"Paid parking, max {paidMax} min" : "Paid parking",
        _ => r.Code
    };

    private static string Describe(ParkingRule r) => $"{Phrase(r)} ({r.Code})";

    // ---------------------------------------------------------------- time helpers

    private DateTime Local(DateTimeOffset instant) => TimeZoneInfo.ConvertTime(instant, _tz).DateTime;

    private DateTimeOffset ToInstant(DateTime wallClock)
    {
        var local = DateTime.SpecifyKind(wallClock, DateTimeKind.Unspecified);
        if (_tz.IsInvalidTime(local)) local = local.AddHours(1);          // spring-forward gap
        var offset = _tz.IsAmbiguousTime(local)
            ? _tz.GetAmbiguousTimeOffsets(local).Max()                    // fall-back hour: first occurrence
            : _tz.GetUtcOffset(local);
        return new DateTimeOffset(local, offset);
    }
}
