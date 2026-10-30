using Npgsql;
using ParkSure.Models;

namespace ParkSure.Repositories;

public sealed record MapCurbRow(int SegmentId, string Side, string GeoJson, string[]? Codes, decimal? MinConfidence);

public class CurbMapRepository
{
    private readonly NpgsqlDataSource _db;
    public CurbMapRepository(NpgsqlDataSource db) => _db = db;

    private const string Sql = @"
        WITH curbs AS (
            SELECT segment_id, side, geom
            FROM street_segment
            WHERE borough = 'MTL'
              AND geom && ST_MakeEnvelope(@minLon, @minLat, @maxLon, @maxLat, 4326)
            LIMIT @limit
        )
        SELECT c.segment_id, c.side,
               ST_AsGeoJSON(CASE WHEN ST_NumGeometries(c.geom) = 1 THEN ST_GeometryN(c.geom, 1) ELSE c.geom END, 6) AS geojson,
               s.codes, s.min_conf
        FROM curbs c
        LEFT JOIN LATERAL (
            SELECT array_agg(DISTINCT p.code_rpa ORDER BY p.code_rpa) AS codes,
                   MIN(l.confidence) AS min_conf
            FROM sign_segment_link l
            JOIN parking_sign p ON p.sign_id = l.sign_id AND p.status = 'active'
            WHERE l.segment_id = c.segment_id
        ) s ON true
        ORDER BY c.segment_id";

    public async Task<List<MapCurbRow>> GetCurbsInBoxAsync(BoundingBox box, int limit, CancellationToken ct)
    {
        await using var cmd = _db.CreateCommand(Sql);
        cmd.Parameters.AddWithValue("minLon", box.MinLon);
        cmd.Parameters.AddWithValue("minLat", box.MinLat);
        cmd.Parameters.AddWithValue("maxLon", box.MaxLon);
        cmd.Parameters.AddWithValue("maxLat", box.MaxLat);
        cmd.Parameters.AddWithValue("limit", limit);

        var list = new List<MapCurbRow>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add(new MapCurbRow(
                r.GetInt32(0), r.GetString(1), r.GetString(2),
                r.IsDBNull(3) ? null : r.GetFieldValue<string[]>(3),
                r.IsDBNull(4) ? null : r.GetDecimal(4)));
        return list;
    }
}
