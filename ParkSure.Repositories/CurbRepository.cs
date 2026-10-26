using Npgsql;
using ParkSure.Models;

namespace ParkSure.Repositories;

public class CurbRepository
{
    private readonly NpgsqlDataSource _db;
    public CurbRepository(NpgsqlDataSource db) => _db = db;

    // The 5 closest curb sides to a pin, nearest first, distance in real metres.
    public async Task<List<CurbCandidate>> FindNearestAsync(double lat, double lon, CancellationToken ct)
    {
        const string sql = @"
            WITH pin AS (SELECT ST_SetSRID(ST_MakePoint(@lon, @lat), 4326) AS g)
            SELECT c.segment_id, c.side, c.street_name, c.borough,
                   ST_Distance(c.geom::geography, pin.g::geography) AS dist_m
            FROM pin
            CROSS JOIN LATERAL (
                SELECT segment_id, side, street_name, borough, geom
                FROM street_segment
                ORDER BY geom <-> pin.g
                LIMIT 5
            ) c
            ORDER BY dist_m";
        await using var cmd = _db.CreateCommand(sql);
        cmd.Parameters.AddWithValue("lat", lat);
        cmd.Parameters.AddWithValue("lon", lon);
        var list = new List<CurbCandidate>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add(new CurbCandidate(r.GetInt32(0), r.GetString(1),
                r.IsDBNull(2) ? null : r.GetString(2),
                r.IsDBNull(3) ? null : r.GetString(3),
                r.GetDouble(4)));
        return list;
    }

    // One curb side by id (used when the user taps a drawn line).
    public async Task<CurbCandidate?> GetCurbAsync(int segmentId, CancellationToken ct)
    {
        await using var cmd = _db.CreateCommand(
            "SELECT segment_id, side, street_name, borough FROM street_segment WHERE segment_id = @id");
        cmd.Parameters.AddWithValue("id", segmentId);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;
        return new CurbCandidate(r.GetInt32(0), r.GetString(1),
            r.IsDBNull(2) ? null : r.GetString(2),
            r.IsDBNull(3) ? null : r.GetString(3), 0);
    }

    // Active signs linked to a curb side. Arrows are ignored.
    public async Task<List<CurbSign>> GetActiveSignsAsync(int segmentId, CancellationToken ct)
    {
        const string sql = @"
            SELECT p.sign_id, p.panneau_id, p.poteau_id, p.code_rpa, p.description_rpa, l.confidence
            FROM sign_segment_link l
            JOIN parking_sign p ON p.sign_id = l.sign_id
            WHERE l.segment_id = @id AND p.status = 'active'
            ORDER BY p.poteau_id, p.position_on_pole, p.sign_id";
        await using var cmd = _db.CreateCommand(sql);
        cmd.Parameters.AddWithValue("id", segmentId);
        var list = new List<CurbSign>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add(new CurbSign(r.GetInt32(0), r.GetString(1),
                r.IsDBNull(2) ? null : r.GetString(2), r.GetString(3),
                r.IsDBNull(4) ? null : r.GetString(4), r.GetDecimal(5)));
        return list;
    }
}