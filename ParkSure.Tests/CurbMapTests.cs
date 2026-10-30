using ParkSure.Evaluation;
using ParkSure.Models;
using ParkSure.Repositories;
using ParkSure.Services;
using Xunit;

namespace ParkSure.Tests;

// B5: the bulk map path must give exactly the answer the single-curb path gives.
public class CurbMapTests
{
    private static readonly Dictionary<string, ParkingRule?> Rules = new()
    {
        ["AD-TT"] = Fx.F1, ["R-PF"] = Fx.F2, ["SU-AE-A"] = Fx.F3, ["PD-TB"] = Fx.F4, ["ON"] = Fx.F5,
        ["BROKEN"] = null   // present in the catalogue but unreadable or unreviewed
    };

    private static MapCurbRow Row(int id, decimal? conf, params string[] codes) =>
        new(id, "Droite", "{\"type\":\"LineString\",\"coordinates\":[[-73.56,45.51],[-73.55,45.51]]}", codes.Length == 0 ? null : codes, conf);

    private static CurbContext Direct(decimal conf, params string[] codes) =>
        new(true, true, codes.Select((c, i) => new LinkedSign(i + 1, c, conf, Rules.GetValueOrDefault(c))).ToList());

    [Theory]
    [InlineData("2026-10-13 14:30")]
    [InlineData("2026-10-13 08:30")]
    [InlineData("2026-10-14 09:30")]
    [InlineData("2026-10-13 03:00")]
    [InlineData("2027-01-06 09:00")]
    public void Bulk_answers_equal_single_curb_answers(string at)
    {
        var rows = new[]
        {
            Row(1, 1.0m, "AD-TT"),
            Row(2, 0.8m, "PD-TB", "R-PF"),
            Row(3, 1.0m, "SU-AE-A"),
            Row(4, 1.0m, "ON"),
            Row(5, 1.0m, "PD-TB", "R-PF"),      // same rule set as row 2: reuses the memoised answer
            Row(6, 1.0m, "AD-TT", "SU-AE-A", "PD-TB"),
        };
        var bulk = CurbMapService.EvaluateRows(rows, Rules, Fx.Ev, Fx.T(at), "198");
        for (int i = 0; i < rows.Length; i++)
        {
            var single = Fx.Ev.Evaluate(Direct(rows[i].MinConfidence!.Value, rows[i].Codes!), Fx.T(at), "198");
            Assert.Equal(single.Status, bulk[i].Status);
            Assert.Equal(single.Reason, bulk[i].Reason);
            Assert.Equal<DateTimeOffset?>(single.ValidUntil, bulk[i].ValidUntil);
        }
    }

    [Fact] // sets that start with the same code must not share an answer
    public void Rule_sets_sharing_a_first_code_are_answered_separately()
    {
        var rows = new[] { Row(1, 1.0m, "PD-TB"), Row(2, 1.0m, "PD-TB", "R-PF") };
        var f = CurbMapService.EvaluateRows(rows, Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Conditions, f[0].Status);   // only the duration limit
        Assert.Equal(CurbStatus.NotAllowed, f[1].Status);   // the permit-only ban applies as well
    }

    [Fact] // a shaky link on one curb must never leak into another curb with the same signs
    public void A_shaky_curb_does_not_poison_a_good_curb_with_the_same_codes()
    {
        var rows = new[] { Row(1, 0.5m, "AD-TT"), Row(2, 1.0m, "AD-TT"), Row(3, 0.5m, "AD-TT") };
        var f = CurbMapService.EvaluateRows(rows, Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(CurbStatus.Unknown, f[0].Status);
        Assert.Equal(CurbStatus.NotAllowed, f[1].Status);
        Assert.Equal(CurbStatus.Unknown, f[2].Status);
    }

    [Fact]
    public void Curb_without_signs_is_gray()
    {
        var f = CurbMapService.EvaluateRows([Row(1, null)], Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null)[0];
        Assert.Equal(CurbStatus.Unknown, f.Status);
    }

    [Fact]
    public void Shaky_link_is_gray_even_when_the_rule_would_forbid()
    {
        var f = CurbMapService.EvaluateRows([Row(1, 0.5m, "AD-TT")], Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null)[0];
        Assert.Equal(CurbStatus.Unknown, f.Status);
    }

    [Fact]
    public void One_unusable_code_hides_the_whole_curb()
    {
        var f = CurbMapService.EvaluateRows([Row(1, 1.0m, "AD-TT", "BROKEN")], Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null)[0];
        Assert.Equal(CurbStatus.Unknown, f.Status);
    }

    [Fact]
    public void Code_missing_from_the_catalogue_is_gray()
    {
        var f = CurbMapService.EvaluateRows([Row(1, 1.0m, "NOT-LOADED")], Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null)[0];
        Assert.Equal(CurbStatus.Unknown, f.Status);
    }

    [Fact]
    public void Permit_changes_the_color_only_for_a_matching_permit_rule()
    {
        var row = new[] { Row(1, 1.0m, "R-PF") };                      // sector 3
        Assert.Equal(CurbStatus.NotAllowed, CurbMapService.EvaluateRows(row, Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null)[0].Status);
        Assert.Equal(CurbStatus.Allowed, CurbMapService.EvaluateRows(row, Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), "3")[0].Status);
        Assert.Equal(CurbStatus.NotAllowed, CurbMapService.EvaluateRows(row, Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), "4")[0].Status);
    }

    [Fact]
    public void Output_order_and_geometry_are_kept()
    {
        var rows = new[] { Row(7, 1.0m, "AD-TT"), Row(3, 1.0m, "ON") };
        var result = CurbMapService.EvaluateRows(rows, Rules, Fx.Ev, Fx.T("2026-10-13 14:30"), null);
        Assert.Equal(7, result[0].SegmentId);
        Assert.Equal(3, result[1].SegmentId);
        Assert.Equal(rows[0].GeoJson, result[0].GeoJson);
    }
}

public class BoundingBoxTests
{
    [Theory]
    [InlineData("-73.57,45.50,-73.55,45.52")]
    [InlineData(" -73.57 , 45.50 , -73.55 , 45.52 ")]
    public void Valid_boxes(string text) => Assert.True(BoundingBox.TryParse(text, out _, out _));

    [Theory]
    [InlineData("")]
    [InlineData("1,2,3")]
    [InlineData("a,b,c,d")]
    [InlineData("-73.55,45.50,-73.57,45.52")]       // min lon bigger than max lon
    [InlineData("-73.57,45.52,-73.55,45.50")]       // min lat bigger than max lat
    [InlineData("-200,45.50,-73.55,45.52")]         // out of range
    [InlineData("-74.00,45.50,-73.50,45.52")]       // 0.5 degrees wide: too large, zoom in
    [InlineData("-73.57,45.40,-73.55,45.70")]       // 0.3 degrees tall: too large
    [InlineData("NaN,45.50,-73.55,45.52")]
    public void Rejected_boxes(string text)
    {
        Assert.False(BoundingBox.TryParse(text, out var box, out var error));
        Assert.Null(box);
        Assert.NotNull(error);
    }
}
