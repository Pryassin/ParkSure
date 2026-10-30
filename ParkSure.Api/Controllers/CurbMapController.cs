using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using ParkSure.Evaluation;
using ParkSure.Models;
using ParkSure.Services;

namespace ParkSure.Controllers;

[ApiController]
[Route("api/curbs")]
public class CurbMapController : ControllerBase
{
    private static readonly Regex HasOffset = new(@"(Z|[+-]\d{2}:\d{2})$", RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private readonly CurbMapService _map;
    public CurbMapController(CurbMapService map) => _map = map;

    // GET /api/curbs?bbox=minLon,minLat,maxLon,maxLat&at=ISO-with-offset&permit=ZONE
    [HttpGet]
    public async Task<IActionResult> Get(
        [FromQuery] string? bbox, [FromQuery] string? at, [FromQuery] string? permit, CancellationToken ct)
    {
        if (!BoundingBox.TryParse(bbox, out var box, out var error))
            return BadRequest(new { error });
        if (permit is { Length: > 32 })
            return BadRequest(new { error = "permit is too long" });

        var moment = DateTimeOffset.UtcNow;
        if (at is not null &&
            (!HasOffset.IsMatch(at) || !DateTimeOffset.TryParse(at, CultureInfo.InvariantCulture, DateTimeStyles.None, out moment)))
            return BadRequest(new { error = "at must be ISO 8601 with a UTC offset, for example 2026-10-14T09:30:00-04:00" });

        var result = await _map.GetAsync(box!, moment, permit, ct);
        return File(WriteFeatureCollection(result, moment), "application/json");
    }

    // Written by hand so the geometry text coming from PostGIS is copied through, not parsed and rebuilt.
    private static byte[] WriteFeatureCollection(MapResult result, DateTimeOffset at)
    {
        using var ms = new MemoryStream();
        using (var w = new Utf8JsonWriter(ms))
        {
            w.WriteStartObject();
            w.WriteString("type", "FeatureCollection");
            w.WriteString("evaluatedAt", at);
            w.WriteBoolean("truncated", result.Truncated);   // true = too many curbs in view, zoom in
            w.WriteStartArray("features");
            foreach (var f in result.Features)
            {
                w.WriteStartObject();
                w.WriteString("type", "Feature");
                w.WriteNumber("id", f.SegmentId);
                w.WritePropertyName("geometry");
                w.WriteRawValue(f.GeoJson, skipInputValidation: true);
                w.WriteStartObject("properties");
                w.WriteNumber("segmentId", f.SegmentId);
                w.WriteString("side", f.Side);
                w.WriteString("status", StatusName(f.Status));
                w.WriteString("reason", f.Reason);
                if (f.ValidUntil is { } until) w.WriteString("validUntil", until); else w.WriteNull("validUntil");
                w.WriteEndObject();
                w.WriteEndObject();
            }
            w.WriteEndArray();
            w.WriteEndObject();
        }
        return ms.ToArray();
    }

    private static string StatusName(CurbStatus s) => s switch
    {
        CurbStatus.Allowed => "allowed",
        CurbStatus.Conditions => "conditions",
        CurbStatus.NotAllowed => "not_allowed",
        _ => "unknown"
    };
}
