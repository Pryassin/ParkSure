using Microsoft.AspNetCore.Mvc;
using ParkSure.Models;
using ParkSure.Services;

namespace ParkSure.Controllers;

[ApiController]
[Route("api/curbs")]
public class CurbsController : ControllerBase
{
    private readonly CurbLookupService _lookup;
    public CurbsController(CurbLookupService lookup) => _lookup = lookup;

    // Temporary for B2: replaced by /api/curbs/at in B4.
    [HttpGet("lookup")]
    public async Task<IActionResult> Lookup(
        [FromQuery] double? lat, [FromQuery] double? lon,
        [FromQuery] string mode = "gps", CancellationToken ct = default)
    {
        if (lat is null || lon is null || !double.IsFinite(lat.Value) || !double.IsFinite(lon.Value)
            || lat < -90 || lat > 90 || lon < -180 || lon > 180)
            return BadRequest(new { error = "lat and lon are required and must be valid coordinates" });

        PinMode m;
        if (mode.Equals("gps", StringComparison.OrdinalIgnoreCase)) m = PinMode.Gps;
        else if (mode.Equals("tap", StringComparison.OrdinalIgnoreCase)) m = PinMode.Tap;
        else return BadRequest(new { error = "mode must be gps or tap" });

        return Ok(Shape(await _lookup.LookupByPointAsync(lat.Value, lon.Value, m, ct)));
    }

    [HttpGet("{segmentId:int}")]
    public async Task<IActionResult> BySegment(int segmentId, CancellationToken ct)
    {
        var result = await _lookup.LookupBySegmentAsync(segmentId, ct);
        return result is null ? NotFound(new { error = "unknown segment" }) : Ok(Shape(result));
    }

    private static string Wire(LookupOutcome o) => o switch
    {
        LookupOutcome.Found => "found",
        LookupOutcome.Ambiguous => "ambiguous",
        LookupOutcome.NoCurb => "no_curb",
        LookupOutcome.NoDataArea => "no_data_area",
        LookupOutcome.NoSigns => "no_signs",
        _ => "unknown"
    };

    private static object Shape(CurbLookupResult r) => new
    {
        outcome = Wire(r.Outcome),
        curbs = r.Curbs.Select(c => new
        {
            segmentId = c.SegmentId, side = c.Side, streetName = c.StreetName,
            borough = c.Borough, distanceM = Math.Round(c.DistanceM, 1)
        }),
        signs = r.Signs.Select(s => new
        {
            signId = s.SignId, panneauId = s.PanneauId, poteauId = s.PoteauId,
            code = s.CodeRpa, text = s.DescriptionRpa, confidence = s.Confidence
        })
    };
}