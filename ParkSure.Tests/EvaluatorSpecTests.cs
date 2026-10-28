using System.Text.Json;
using ParkSure.Evaluation;
using Xunit;

namespace ParkSure.Tests;

// Sections 1 to 8 of evaluator-tests-v1.md. Boundaries: start-inclusive, end-exclusive; 60-minute look-ahead inclusive.

public class Section1_SingleRule
{
    [Theory]
    [InlineData("2026-10-13 14:30", CurbStatus.NotAllowed, "2026-10-13 23:00")] // 1.1
    [InlineData("2026-10-13 23:30", CurbStatus.Allowed, "2026-10-14 09:00")]    // 1.2
    [InlineData("2026-10-13 08:30", CurbStatus.Conditions, "2026-10-13 09:00")] // 1.3
    [InlineData("2026-10-13 07:59", CurbStatus.Allowed, "2026-10-13 09:00")]    // 1.4
    [InlineData("2026-10-13 09:00", CurbStatus.NotAllowed, "2026-10-13 23:00")] // 1.5
    [InlineData("2026-10-13 23:00", CurbStatus.Allowed, "2026-10-14 09:00")]    // 1.6
    public void R_PF_without_permit(string at, CurbStatus expected, string until)
    {
        var r = Fx.Run(Fx.Curb(Fx.F2), at);
        Assert.Equal(expected, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.VU(until), r.ValidUntil);
    }
}

public class Section2_Overnight
{
    [Theory]
    [InlineData("2026-10-13 03:00", CurbStatus.NotAllowed, "2026-10-13 07:00")] // 2.1
    [InlineData("2026-10-13 07:30", CurbStatus.Allowed, "2026-10-13 19:00")]    // 2.2
    [InlineData("2026-10-13 18:30", CurbStatus.Conditions, "2026-10-13 19:00")] // 2.3
    [InlineData("2026-10-13 18:00", CurbStatus.Conditions, "2026-10-13 19:00")] // 2.4 exactly 60 min
    [InlineData("2026-10-13 17:59", CurbStatus.Allowed, "2026-10-13 19:00")]    // 2.5 61 min
    [InlineData("2026-10-12 00:30", CurbStatus.Allowed, "2026-10-12 19:00")]    // 2.6
    [InlineData("2026-10-17 03:00", CurbStatus.NotAllowed, "2026-10-17 07:00")] // 2.7
    [InlineData("2026-10-18 03:00", CurbStatus.Allowed, "2026-10-19 19:00")]    // 2.8
    [InlineData("2026-10-13 07:00", CurbStatus.Allowed, "2026-10-13 19:00")]    // 2.9
    [InlineData("2026-10-13 19:00", CurbStatus.NotAllowed, "2026-10-14 07:00")] // 2.10
    public void Overnight_Mon_to_Fri(string at, CurbStatus expected, string until)
    {
        var r = Fx.Run(Fx.Curb(Fx.F5), at);
        Assert.Equal(expected, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.VU(until), r.ValidUntil);
    }
}

public class Section3_SeasonalWrap
{
    [Fact] // 3.1 window started Mon Nov 30 19:00, November is in season
    public void Dec1_0300_still_in_Novembers_window()
    {
        var r = Fx.Run(Fx.Curb(Fx.F6), "2026-12-01 03:00");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-12-01 07:00"), r.ValidUntil);
    }

    [Fact] // 3.2 window would have started Tue Dec 1, December is out of season.
    public void Dec2_0300_out_of_season()                  // NOTE: the tests file says Mon 2027-04-05; 2027-04-01 is a Thursday.
    {
        var r = Fx.Run(Fx.Curb(Fx.F6), "2026-12-02 03:00");
        Assert.Equal(CurbStatus.Allowed, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.T("2027-04-01 19:00"), r.ValidUntil);
    }

    [Fact] // 3.3 cleaning is a Wednesday rule, January is out of season
    public void Cleaning_in_January()
    {
        var r = Fx.Run(Fx.Curb(Fx.F3), "2027-01-06 09:00");
        Assert.Equal(CurbStatus.Allowed, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.T("2027-04-07 08:30"), r.ValidUntil);
    }
}

public class Section4_MostRestrictiveWins
{
    [Fact] // 4.1
    public void Ban_beats_duration_limit()
    {
        var r = Fx.Run(Fx.Curb(Fx.F2, Fx.F4), "2026-10-13 14:30");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal("R-PF", r.DecidingCode);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-10-13 23:00"), r.ValidUntil);
    }

    [Fact] // 4.2
    public void Only_the_limit_is_active()
    {
        var r = Fx.Run(Fx.Curb(Fx.F2, Fx.F4), "2026-10-13 08:30");
        Assert.Equal(CurbStatus.Conditions, r.Status);
        Assert.Equal("PD-TB", r.DecidingCode);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-10-13 09:00"), r.ValidUntil);
    }

    [Fact] // 4.3
    public void Both_closed()
    {
        var r = Fx.Run(Fx.Curb(Fx.F2, Fx.F4), "2026-10-13 23:30");
        Assert.Equal(CurbStatus.Allowed, r.Status);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-10-14 08:00"), r.ValidUntil);
    }
}

public class Section5_PriorityIsOnlyTheMessage
{
    [Fact]
    public void Lower_priority_number_gives_the_reason_and_the_ban_never_ends()
    {
        var r = Fx.Run(Fx.Curb(Fx.F1, Fx.F2), "2026-10-13 14:30");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal("AD-TT", r.DecidingCode);
        Assert.Null(r.ValidUntil);
    }

    [Fact] // the bulk load gives every ban priority 10: ties go to the stronger kind, then to the code
    public void Equal_priorities_are_broken_deterministically()
    {
        var noStopping = Fx.F1 with { Priority = 10 };
        var r = Fx.Run(Fx.Curb(Fx.F2, noStopping), "2026-10-13 14:30");
        Assert.Equal("AD-TT", r.DecidingCode);
    }
}

public class Section6_Unknown
{

    [Fact] // 6.1
    public void No_curb()
    {
        var r = Fx.Ev.Evaluate(new CurbContext(false, true, []), Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Unknown, r.Status);
        Assert.Equal<UnknownReason?>(UnknownReason.NoCurb, r.UnknownReason);
        Assert.Null(r.ValidUntil);
    }

    [Fact] // 6.2
    public void No_signs_is_never_green()
    {
        var r = Fx.Ev.Evaluate(new CurbContext(true, true, []), Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Unknown, r.Status);
        Assert.Equal<UnknownReason?>(UnknownReason.NoSigns, r.UnknownReason);
    }

    [Fact] // 6.3 link confidence 0.5, rule would forbid
    public void Low_confidence_is_checked_before_any_rule()
    {
        var ctx = new CurbContext(true, true, [new LinkedSign(1, "R-PF", 0.5m, Fx.F2)]);
        var r = Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Unknown, r.Status);
        Assert.Equal<UnknownReason?>(UnknownReason.LowConfidence, r.UnknownReason);
    }

    [Fact]
    public void Exactly_0_6_passes()
    {
        var ctx = new CurbContext(true, true, [new LinkedSign(1, "AD-TT", 0.6m, Fx.F1)]);
        Assert.Equal(CurbStatus.NotAllowed, Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null).Status);
    }

    [Fact] // 6.4 an unusable code hides the whole curb even though another sign forbids
    public void Missing_rule_masks_the_curb()
    {
        var ctx = new CurbContext(true, true, [new LinkedSign(1, "X-NEW", 1.0m, null), new LinkedSign(2, "AD-TT", 1.0m, Fx.F1)]);
        var r = Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Unknown, r.Status);
        Assert.Equal<UnknownReason?>(UnknownReason.NoRule, r.UnknownReason);
        Assert.Equal("X-NEW", string.Join(",", r.MissingCodes));
    }

    [Fact] // one log row per distinct missing code
    public void Missing_codes_are_distinct_and_sorted()
    {
        var ctx = new CurbContext(true, true, [new LinkedSign(1, "B-2", 1.0m, null), new LinkedSign(2, "A-1", 1.0m, null), new LinkedSign(3, "B-2", 1.0m, null)]);
        var r = Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal("A-1,B-2", string.Join(",", r.MissingCodes));
    }

    [Fact] // check order: low_confidence before no_rule
    public void Low_confidence_wins_over_missing_rule()
    {
        var ctx = new CurbContext(true, true, [new LinkedSign(1, "X-NEW", 0.5m, null)]);
        Assert.Equal<UnknownReason?>(UnknownReason.LowConfidence, Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null).UnknownReason);
    }

    [Fact] // 6.5 fixture is DDO (not Ile-Bizard): a curb outside the covered area
    public void No_data_area()
    {
        var ctx = new CurbContext(true, false, [new LinkedSign(1, "AD-TT", 1.0m, Fx.F1)]);
        var r = Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal<UnknownReason?>(UnknownReason.NoDataArea, r.UnknownReason);
    }

    [Fact] // locked in piece 2: no_data_area is checked before no_signs
    public void No_data_area_comes_before_no_signs()
    {
        var r = Fx.Ev.Evaluate(new CurbContext(true, false, []), Fx.T("2026-10-13 14:30"), null);
        Assert.Equal<UnknownReason?>(UnknownReason.NoDataArea, r.UnknownReason);
    }
}

public class Section7_Determinism
{
    [Theory] // 7.1
    [InlineData("2026-10-13 14:30")]
    [InlineData("2026-12-25 03:00")]
    [InlineData("2027-07-01 23:59")]
    public void Always_active_ban(string at)
    {
        var r = Fx.Run(Fx.Curb(Fx.F1), at);
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Null(r.ValidUntil);
    }

    [Fact] // 7.2
    public void Same_input_gives_identical_output()
    {
        var curb = Fx.Curb(Fx.F2, Fx.F3, Fx.F4, Fx.F5);
        var a = JsonSerializer.Serialize(Fx.Run(curb, "2026-10-14 09:30", "198"));
        var b = JsonSerializer.Serialize(Fx.Run(curb, "2026-10-14 09:30", "198"));
        Assert.Equal(a, b);
    }

    [Fact] // 7.3 arrows change nothing
    public void Arrow_values_are_ignored()
    {
        string? Run(string arrow)
        {
            var ctx = new CurbContext(true, true, [new LinkedSign(1, "AD-TT", 1.0m, Fx.F1, arrow), new LinkedSign(2, "PD-TB", 1.0m, Fx.F4, arrow)]);
            return JsonSerializer.Serialize(Fx.Ev.Evaluate(ctx, Fx.T("2026-10-13 14:30"), null));
        }
        var baseline = Run("0");
        Assert.Equal(baseline, Run("2"));
        Assert.Equal(baseline, Run("3"));
        Assert.Equal(baseline, Run("8"));
    }
}

public class Section8_Permit
{
    [Theory]
    [InlineData("198", CurbStatus.Allowed, "permit 198 accepted", "")]          // 8.1
    [InlineData("199", CurbStatus.NotAllowed, "", "2026-10-13 23:00")]          // 8.2
    [InlineData("", CurbStatus.NotAllowed, "", "2026-10-13 23:00")]             // 8.3
    [InlineData("0198", CurbStatus.Allowed, "permit 198 accepted", "")]         // 8.4
    [InlineData(" 198 ", CurbStatus.Allowed, "permit 198 accepted", "")]        // 8.5
    [InlineData("000", CurbStatus.NotAllowed, "", "2026-10-13 23:00")]          // 8.6
    [InlineData("3,198", CurbStatus.NotAllowed, "", "2026-10-13 23:00")]        // 8.7
    public void F7_alone(string permit, CurbStatus expected, string reason, string until)
    {
        var r = Fx.Run(Fx.Curb(Fx.F7), "2026-10-13 14:30", permit);
        Assert.Equal(expected, r.Status);
        if (reason != "") Assert.Equal(reason, r.Reason);
        Assert.Equal<DateTimeOffset?>(Fx.VU(until), r.ValidUntil);
    }

    [Fact]
    public void No_permit_given_at_all()
    {
        var r = Fx.Run(Fx.Curb(Fx.F7), "2026-10-13 14:30", null);
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
    }

    [Fact] // 8.8 bypassing one rule never un-forbids another
    public void Permit_does_not_beat_an_always_active_ban()
    {
        var r = Fx.Run(Fx.Curb(Fx.F7, Fx.F1), "2026-10-13 14:30", "198");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal("AD-TT", r.DecidingCode);
        Assert.Null(r.ValidUntil);
    }

    [Fact] // 8.9
    public void Permit_does_not_beat_cleaning()
    {
        var r = Fx.Run(Fx.Curb(Fx.F7, Fx.F3), "2026-10-14 09:30", "198");
        Assert.Equal(CurbStatus.NotAllowed, r.Status);
        Assert.Equal("SU-AE-A", r.DecidingCode);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-10-14 11:30"), r.ValidUntil);
    }

    [Fact] // 8.10
    public void Permit_removes_the_ban_but_not_the_limit()
    {
        var r = Fx.Run(Fx.Curb(Fx.F7, Fx.F4), "2026-10-13 14:30", "198");
        Assert.Equal(CurbStatus.Conditions, r.Status);
        Assert.Equal("PD-TB", r.DecidingCode);
        Assert.Equal(120, r.MaxMinutes);
        Assert.Equal<DateTimeOffset?>(Fx.T("2026-10-13 18:00"), r.ValidUntil);
    }
}
