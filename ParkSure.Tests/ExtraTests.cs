using ParkSure.Evaluation;
using Xunit;

namespace ParkSure.Tests;

// Extras beyond evaluator-tests-v1.md: the six piece-5 corrections, the parser, normalisation, end of day, DST.

public class Corrections_Piece5
{
    private static readonly ParkingRule Paid = new("PP-AQ", RuleKind.PaidParking, 60, []);

    [Fact] // correction 1: prohibitions override permissions in overlapping windows
    public void Ban_and_limit_overlap_ban_wins_and_nothing_goes_unknown()
    {
        var r = Fx.Run(Fx.Curb(Fx.F3, Fx.F4), "2026-10-14 09:30");   // cleaning Wed 08:30-11:30 + limit 08:00-18:00
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal("SU-AE-A", r.DecidingCode);
    }

    [Fact] // correction 2: no permit unless one is provided; a rule without a sector matches nobody
    public void Permit_rule_with_null_sector_never_matches()
    {
        var noSector = Fx.F7 with { PermitSector = null };
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(noSector), "2026-10-13 14:30", "198").Status);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(noSector), "2026-10-13 14:30", "").Status);
    }

    [Fact] // correction 2: a permit only cancels no_parking_except_permit, never a plain ban
    public void Permit_value_cannot_cancel_a_plain_no_parking()
    {
        var plain = Fx.F5 with { PermitSector = "198" };
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(plain), "2026-10-13 20:00", "198").Status);
    }

    [Fact] // correction 3: season comes from each rule's months, Apr-Dec in, Jan-Mar out
    public void Cleaning_season_Apr_to_Dec()
    {
        Assert.Equal(CurbStatus.Allowed, Fx.Run(Fx.Curb(Fx.F3), "2027-03-31 09:30").Status);   // Wed, March
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(Fx.F3), "2027-04-07 09:30").Status); // Wed, April
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(Fx.F3), "2026-12-30 09:30").Status); // Wed, December (over-covered)
        Assert.Equal(CurbStatus.Allowed, Fx.Run(Fx.Curb(Fx.F3), "2027-01-06 09:30").Status);    // Wed, January
    }

    [Fact] // correction 5: paid is conditions, never plain allowed
    public void Paid_parking_is_conditions()
    {
        var r = Fx.Run(Fx.Curb(Paid), "2026-10-13 14:30");
        Assert.Equal(CurbStatus.Conditions, r.Status);
        Assert.True(r.PaymentRequired);
        Assert.Equal("PP-AQ", r.DecidingCode);
        Assert.Null(r.ValidUntil);
    }

    [Fact] // correction 5: the max duration is shown, the smallest active limit wins
    public void Paid_plus_limit_shows_the_max_duration()
    {
        var r = Fx.Run(Fx.Curb(Paid, Fx.F4), "2026-10-13 14:30");
        Assert.Equal(CurbStatus.Conditions, r.Status);
        Assert.True(r.PaymentRequired);
        Assert.Equal(120, r.MaxMinutes);
        Assert.Equal("PD-TB", r.DecidingCode);   // equal-ish kinds: lower priority number (50) beats paid (60)
    }

    [Fact] // paid is nullified by a ban
    public void Ban_cancels_payment_details()
    {
        var r = Fx.Run(Fx.Curb(Paid, Fx.F1), "2026-10-13 14:30");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.False(r.PaymentRequired);
    }

    [Fact] // a permit value must not soften a plain ban, including in the 60-minute warning
    public void Permit_value_does_not_soften_the_warning_of_a_plain_ban()
    {
        var plain = Fx.F5 with { PermitSector = "198" };
        var r = Fx.Run(Fx.Curb(plain), "2026-10-13 18:30", "198");   // ban starts 19:00
        Assert.Equal(CurbStatus.Conditions, r.Status);
        Assert.Equal("ON", r.DecidingCode);
    }

    [Fact] // valid_until is the next change of the base answer; the 60-minute warning never creates one
    public void Valid_until_ignores_the_warning_even_when_another_window_ends_just_before_a_ban()
    {
        var permitWindow = new ParkingRule("R-PF", RuleKind.NoParkingExceptPermit, 10, [Fx.W(null, "09:00", "18:30")], PermitSector: "198");
        var r = Fx.Run(Fx.Curb(permitWindow, Fx.F5), "2026-10-13 12:00", "198");
        Assert.Equal(CurbStatus.Allowed, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-10-13 19:00"), r.ValidUntil);
    }

    [Fact] // correction 6: contradictions resolve to prohibition and never to unknown
    public void Contradictions_do_not_become_unknown()
    {
        var r = Fx.Run(Fx.Curb(Fx.F1, Fx.F4, Fx.F5), "2026-10-13 20:00");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Null(r.UnknownReason);
    }
}

public class EndOfDayAndDst
{
    [Fact] // decision: to = "23:59" means end of day, so an all-day ban has no gap
    public void All_day_ban_at_2359_is_still_a_ban()
    {
        var allDay = new ParkingRule("ALL", RuleKind.NoParking, 10, [Fx.W(null, "00:00", "23:59")]);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(allDay), "2026-10-13 23:59").Status);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(allDay), "2026-10-14 00:00").Status);
        Assert.Null(Fx.Run(Fx.Curb(allDay), "2026-10-13 12:00").ValidUntil);
    }

    [Fact]
    public void Window_ending_at_midnight_is_exact()
    {
        var evening = new ParkingRule("SD-SR", RuleKind.NoParking, 10, [Fx.W(null, "18:00", "00:00")]);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(evening), "2026-10-13 23:59").Status);
        var r = Fx.Run(Fx.Curb(evening), "2026-10-14 00:00");
        Assert.Equal(CurbStatus.Allowed, r.Status);
    }

    [Theory] // spring-forward Sunday 2027-03-14: 02:00 jumps to 03:00
    [InlineData("2027-03-14 01:30")]
    [InlineData("2027-03-14 03:30")]
    public void Overnight_window_across_the_clock_change(string at)
    {
        var night = new ParkingRule("NIGHT", RuleKind.NoParking, 10, [Fx.W(null, "22:00", "06:00")]);
        var r = Fx.Run(Fx.Curb(night), at);
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.T("2027-03-14 06:00"), r.ValidUntil);
    }
}

public class IsoDays
{
    [Theory] // Sunday is day 7 (ISO), Monday is day 1
    [InlineData("2026-10-18 14:30", CurbStatus.NotAllowed)]   // Sunday
    [InlineData("2026-10-17 14:30", CurbStatus.Allowed)]      // Saturday
    [InlineData("2026-10-19 14:30", CurbStatus.Allowed)]      // Monday
    public void Sunday_only_rule(string at, CurbStatus expected)
    {
        var sunday = new ParkingRule("SU-PB", RuleKind.NoParking, 10, [Fx.W(new[] { 7 }, "14:00", "15:00")]);
        Assert.Equal(expected, Fx.Run(Fx.Curb(sunday), at).Status);
    }
}

public class Normalisation
{
    [Theory]
    [InlineData("052-E", "52e")]
    [InlineData("052", "52")]
    [InlineData(" 198 ", "198")]
    [InlineData("000", "")]
    [InlineData("3,198", "3198")]
    [InlineData("S03R", "s3r")]
    [InlineData("---", "")]
    [InlineData("", "")]
    public void Permit_normalisation(string raw, string expected) =>
        Assert.Equal(expected, CurbEvaluator.NormalizePermit(raw));
}

public class RuleParserTests
{
    private const string CleaningJson = "[{\"days\":[3],\"from\":\"08:30\",\"to\":\"11:30\",\"months\":[4,5,6,7,8,9,10,11,12]}]";

    [Fact]
    public void Reads_the_cleaning_rule_and_it_evaluates()
    {
        var rule = RuleParser.TryParse("SU-AE-A", "no_parking", 10, true, CleaningJson, null, null, out var problem);
        Assert.Null(problem);
        Assert.NotNull(rule);
        Assert.Equal(510, rule!.Windows[0].FromMinute);
        Assert.Equal(690, rule.Windows[0].ToMinute);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(rule), "2026-10-14 09:30").Status);
        Assert.Equal(CurbStatus.Allowed, Fx.Run(Fx.Curb(rule), "2027-01-06 09:30").Status);
    }

    [Fact]
    public void Empty_array_means_always_active()
    {
        var rule = RuleParser.TryParse("AD-TT", "no_stopping", 10, true, "[]", null, null, out _);
        Assert.NotNull(rule);
        Assert.Empty(rule!.Windows);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Run(Fx.Curb(rule), "2026-10-13 03:00").Status);
    }

    [Theory]
    [InlineData("{}")]                                                                 // not an array
    [InlineData("not json")]
    [InlineData("[{\"from\":\"08:00\"}]")]                                             // missing to
    [InlineData("[{\"from\":\"8:00\",\"to\":\"09:00\"}]")]                             // bad format
    [InlineData("[{\"from\":\"24:00\",\"to\":\"06:00\"}]")]                            // 24:00 is not valid
    [InlineData("[{\"from\":\"09:00\",\"to\":\"09:00\"}]")]                            // from equals to
    [InlineData("[{\"days\":[],\"from\":\"08:00\",\"to\":\"09:00\"}]")]                // empty days
    [InlineData("[{\"days\":[8],\"from\":\"08:00\",\"to\":\"09:00\"}]")]               // day out of range
    [InlineData("[{\"months\":[13],\"from\":\"08:00\",\"to\":\"09:00\"}]")]            // month out of range
    [InlineData("[{\"days\":\"1\",\"from\":\"08:00\",\"to\":\"09:00\"}]")]             // days not a list
    [InlineData("[{\"season\":{\"from\":\"04-01\",\"to\":\"12-01\"},\"from\":\"08:00\",\"to\":\"09:00\"}]")] // different format
    public void Unreadable_windows_are_rejected(string json)
    {
        var rule = RuleParser.TryParse("X-1", "no_parking", 10, true, json, null, null, out var problem);
        Assert.Null(rule);
        Assert.NotNull(problem);
    }

    [Fact]
    public void Null_windows_are_rejected()
    {
        Assert.Null(RuleParser.TryParse("X-1", "no_parking", 10, true, null, null, null, out var problem));
        Assert.NotNull(problem);
    }

    [Fact]
    public void Unreviewed_rows_are_rejected()
    {
        Assert.Null(RuleParser.TryParse("X-1", "no_parking", 10, false, "[]", null, null, out var problem));
        Assert.Contains("not reviewed", problem!);
    }

    [Theory] // PD-TD (reserved) is still undecided, so it must not become a rule by accident
    [InlineData("reserved")]
    [InlineData("reserved_hotel")]
    [InlineData("")]
    public void Unrecognised_types_are_rejected(string type)
    {
        Assert.Null(RuleParser.TryParse("PD-TD", type, 10, true, "[]", null, null, out var problem));
        Assert.NotNull(problem);
    }

    [Fact] // a rejected rule becomes "no usable rule" and the curb is unknown, never allowed
    public void Rejected_rule_makes_the_curb_unknown()
    {
        var ctx = new CurbContext(true, true, [new LinkedSign(1, "PD-TD", 1.0m, null)]);
        var r = Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Unknown, r.Status);
        Assert.Equal("PD-TD", string.Join(",", r.MissingCodes));
    }
}
