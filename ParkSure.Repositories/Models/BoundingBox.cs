using System.Globalization;

namespace ParkSure.Models;

/// <summary>The visible map area, as the app sends it: minLon,minLat,maxLon,maxLat (WGS84).</summary>
public sealed record BoundingBox(double MinLon, double MinLat, double MaxLon, double MaxLat)
{
    public const double MaxSpanLon = 0.07;   // about 5.4 km at Montreal's latitude
    public const double MaxSpanLat = 0.05;   // about 5.6 km

    public static bool TryParse(string? text, out BoundingBox? box, out string error)
    {
        box = null; error = "";
        var parts = text?.Split(',', StringSplitOptions.TrimEntries);
        if (parts is null || parts.Length != 4) { error = "bbox must be minLon,minLat,maxLon,maxLat"; return false; }

        var v = new double[4];
        for (int i = 0; i < 4; i++)
            if (!double.TryParse(parts[i], NumberStyles.Float, CultureInfo.InvariantCulture, out v[i]) || !double.IsFinite(v[i]))
            { error = "bbox values must be numbers"; return false; }

        var (minLon, minLat, maxLon, maxLat) = (v[0], v[1], v[2], v[3]);
        if (minLon < -180 || maxLon > 180 || minLat < -90 || maxLat > 90) { error = "bbox is outside valid coordinates"; return false; }
        if (minLon >= maxLon || minLat >= maxLat) { error = "bbox min values must be smaller than max values"; return false; }
        if (maxLon - minLon > MaxSpanLon || maxLat - minLat > MaxSpanLat) { error = "bbox is too large, zoom in"; return false; }

        box = new BoundingBox(minLon, minLat, maxLon, maxLat);
        return true;
    }
}