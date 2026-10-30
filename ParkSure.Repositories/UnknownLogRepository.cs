using Npgsql;

namespace ParkSure.Repositories;

public sealed record UnknownLogEntry(DateTime QueriedAtUtc, decimal Lat, decimal Lon,
                                     int? SegmentId, string Reason, string? CodeRpa);

public class UnknownLogRepository
{
    private readonly NpgsqlDataSource _db;
    public UnknownLogRepository(NpgsqlDataSource db) => _db = db;

    // All rows of one query are written together or not at all.
    public async Task InsertAsync(IReadOnlyList<UnknownLogEntry> rows, CancellationToken ct)
    {
        if (rows.Count == 0) return;
        await using var conn = await _db.OpenConnectionAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(ct);
        foreach (var row in rows)
        {
            await using var cmd = new NpgsqlCommand(
                @"INSERT INTO unknown_log (queried_at, lat, lon, segment_id, reason, code_rpa)
                  VALUES (@t, @lat, @lon, @seg, @reason, @code)", conn, tx);
            cmd.Parameters.AddWithValue("t", row.QueriedAtUtc);
            cmd.Parameters.AddWithValue("lat", row.Lat);
            cmd.Parameters.AddWithValue("lon", row.Lon);
            cmd.Parameters.AddWithValue("seg", (object?)row.SegmentId ?? DBNull.Value);
            cmd.Parameters.AddWithValue("reason", row.Reason);
            cmd.Parameters.AddWithValue("code", (object?)row.CodeRpa ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync(ct);
        }
        await tx.CommitAsync(ct);
    }
}
