using System.Globalization;
using ParkSure.Evaluation;

namespace ParkSure.Tests;

/// <summary>Fixtures F1..F7 from evaluator-tests-v1.md, plus small helpers. Logic tests use these injected rules, never the database.</summary>
internal static class Fx
{
    public static readonly TimeZoneInfo Tz = CurbEvaluator.FindToronto();
    public static readonly CurbEvaluator Ev = new(Tz);

    public static RuleWindow W(int[]? days, string from, string to, int[]? months = null) =>
        RuleWindow.TryCreate(days, from, to, months) ?? throw new InvalidOperationException("bad test window");

    // "2026-10-13 14:30" read as America/Toronto wall-clock time.
    public static DateTimeOffset T(string local)
    {
        var dt = DateTime.ParseExact(local, "yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture);
        return new DateTimeOffset(dt, Tz.GetUtcOffset(dt));
    }

    public static DateTimeOffset? VU(string until) => string.IsNullOrEmpty(until) ? null : T(until);

    private static readonly int[] Weekdays = { 1, 2, 3, 4, 5 };
    private static int[] Months(int from, int to) => Enumerable.Range(from, to - from + 1).ToArray();

    public static readonly ParkingRule F1 = new("AD-TT", RuleKind.NoStopping, 5, []);
    public static readonly ParkingRule F2 = new("R-PF", RuleKind.NoParkingExceptPermit, 10, [W(null, "09:00", "23:00")], PermitSector: "3");
    public static readonly ParkingRule F3 = new("SU-AE-A", RuleKind.NoParking, 10, [W(new[] { 3 }, "08:30", "11:30", Months(4, 12))]);
    public static readonly ParkingRule F4 = new("PD-TB", RuleKind.DurationLimit, 50, [W(null, "08:00", "18:00")], MaxMinutes: 120);
    public static readonly ParkingRule F5 = new("ON", RuleKind.NoParking, 10, [W(Weekdays, "19:00", "07:00")]);
    public static readonly ParkingRule F6 = new("ON-S", RuleKind.NoParking, 10, [W(Weekdays, "19:00", "07:00", Months(4, 11))]);
    public static readonly ParkingRule F7 = new("R-PF", RuleKind.NoParkingExceptPermit, 10, [W(null, "09:00", "23:00")], PermitSector: "198");

    /// <summary>A curb in the covered area where every sign is linked with confidence 1.0.</summary>
    public static CurbContext Curb(params ParkingRule[] rules) =>
        new(true, true, rules.Select((r, i) => new LinkedSign(i + 1, r.Code, 1.0m, r)).ToList());

    public static EvaluationResult Run(CurbContext curb, string at, string? permit = null) => Ev.Evaluate(curb, T(at), permit);
}
