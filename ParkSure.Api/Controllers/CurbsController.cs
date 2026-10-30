using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using ParkSure.Evaluation;
using ParkSure.Models;
using ParkSure.Services;

namespace ParkSure.Controllers;

[ApiController]
[Route("api/curbs")]
public class CurbsController : ControllerBase
{
    private static readonly Regex HasOffset = new(@"(Z|[+-]\d{2}:\d{2})$", RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private readonly CurbLookupService _lookup;
    private readonly CurbStatusService _status;
    public CurbsController(CurbLookupService lookup, CurbStatusService status) { _lookup = lookup; _status = status; }

    // The answer: status, reason, valid-until, signs. Single-curb query (a tap or a GPS check).
    [HttpGet("at")]
    public async Task<IActionResult> At(
        [FromQuery] double? lat, [FromQuery] double? lon,
        [FromQuery] string mode = "gps", [FromQuery] int? segmentId = null,
        [FromQuery] string? at = null, [FromQuery] string? permit = null,
        CancellationToken ct = default)
    {
        if (!TryPoint(lat, lon, out var latV, out var lonV))
            return BadRequest(new { error = "lat and lon are required and must be valid coordinates" });
        if (!TryMode(mode, out var pinMode))
            return BadRequest(new { error = "mode must be gps or tap" });
        if (permit is { Length: > 32 })
            return BadRequest(new { error = "permit is too long" });

        var moment = DateTimeOffset.UtcNow;
        if (at is not null &&
            (!HasOffset.IsMatch(at) || !DateTimeOffset.TryParse(at, CultureInfo.InvariantCulture, DateTimeStyles.None, out moment)))
            return BadRequest(new { error = "at must be ISO 8601 with a UTC offset, for example 2026-10-14T09:30:00-04:00" });

        var response = await _status.GetAsync(latV, lonV, pinMode, segmentId, moment, permit, ct);
        return response is null ? NotFound(new { error = "unknown segment" }) : Ok(ShapeAnswer(response));
    }

    // Kept from B2 for debugging: the lookup without the evaluator.
    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(
        [FromQuery] double? lat, [FromQuery] double? lon,
        [FromQuery] string mode = "gps", CancellationToken ct = default)
    {
        if (!TryPoint(lat, lon, out var latV, out var lonV))
            return BadRequest(new { error = "lat and lon are required and must be valid coordinates" });
        if (!TryMode(mode, out var pinMode))
            return BadRequest(new { error = "mode must be gps or tap" });
        return Ok(ShapeLookup(await _lookup.LookupByPointAsync(latV, lonV, pinMode, ct)));
    }

    [HttpGet("{segmentId:int}")]
    public async Task<IActionResult> BySegment(int segmentId, CancellationToken ct)
    {
        var result = await _lookup.LookupBySegmentAsync(segmentId, ct);
        return result is null ? NotFound(new { error = "unknown segment" }) : Ok(ShapeLookup(result));
    }

    // ---------------------------------------------------------------- helpers

    private static bool TryPoint(double? lat, double? lon, out double latV, out double lonV)
    {
        latV = lat ?? 0; lonV = lon ?? 0;
        return lat is not null && lon is not null && double.IsFinite(latV) && double.IsFinite(lonV)
            && latV is >= -90 and <= 90 && lonV is >= -180 and <= 180;
    }

    private static bool TryMode(string mode, out PinMode result)
    {
        result = PinMode.Gps;
        if (mode.Equals("gps", StringComparison.OrdinalIgnoreCase)) return true;
        if (mode.Equals("tap", StringComparison.OrdinalIgnoreCase)) { result = PinMode.Tap; return true; }
        return false;
    }

    private static string StatusName(CurbStatus s) => s switch
    {
        CurbStatus.Allowed => "allowed",
        CurbStatus.Conditions => "conditions",
        CurbStatus.NotAllowed => "not_allowed",
        _ => "unknown"
    };

    private static List<object> ShapeCurbs(IEnumerable<CurbCandidate> curbs) => curbs.Select(c => (object)new
    {
        segmentId = c.SegmentId, side = c.Side, streetName = c.StreetName,
        borough = c.Borough, distanceM = Math.Round(c.DistanceM, 1)
    }).ToList();

    private static List<object> ShapeSigns(IEnumerable<CurbSign> signs) => signs.Select(s => (object)new
    {
        signId = s.SignId, code = s.CodeRpa, text = s.DescriptionRpa, confidence = s.Confidence
    }).ToList();

    private static object ShapeAnswer(CurbStatusResponse r)
    {
        if (r.Evaluation is null)   // ambiguous: the user must pick a side
            return new { outcome = r.Outcome, curbs = ShapeCurbs(r.Curbs) };

        var e = r.Evaluation;
        return new
        {
            outcome = r.Outcome,
            status = StatusName(e.Status),
            reason = e.Reason,
            unknownReason = e.UnknownReason is { } u ? CurbStatusService.ReasonName(u) : null,
            decidingCode = e.DecidingCode,
            validUntil = e.ValidUntil,
            paymentRequired = e.PaymentRequired,
            maxMinutes = e.MaxMinutes,
            activeCodes = e.ActiveCodes,
            curb = ShapeCurbs(r.Curbs).FirstOrDefault(),
            signs = ShapeSigns(r.Signs),
            disclaimer = "Permitted does not mean a free spot. Always check the posted signs."
        };
    }

    private static string LookupName(LookupOutcome o) => o switch
    {
        LookupOutcome.Found => "found", LookupOutcome.Ambiguous => "ambiguous", LookupOutcome.NoCurb => "no_curb",
        LookupOutcome.NoDataArea => "no_data_area", LookupOutcome.NoSigns => "no_signs", _ => "unknown"
    };

    private static object ShapeLookup(CurbLookupResult r) =>
        new { outcome = LookupName(r.Outcome), curbs = ShapeCurbs(r.Curbs), signs = ShapeSigns(r.Signs) };
}