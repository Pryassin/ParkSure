using Npgsql;

namespace ParkSure.Repositories;

public class StatsRepository
{
    private readonly NpgsqlDataSource _db;
    public StatsRepository(NpgsqlDataSource db) => _db = db;

    private static readonly string[] Tables =
    {
        "parking_sign", "rpa_code", "parking_rule", "street_segment",
        "sign_segment_link", "data_sync", "unknown_log"
    };

    public async Task<Dictionary<string, long>> CountRowsAsync(CancellationToken ct)
    {
        var result = new Dictionary<string, long>();
        await using var conn = await _db.OpenConnectionAsync(ct);
        foreach (var table in Tables)   // names come from the fixed list above, never from user input
        {
            await using var cmd = new NpgsqlCommand($"SELECT COUNT(*) FROM {table}", conn);
            result[table] = (long)(await cmd.ExecuteScalarAsync(ct))!;
        }
        return result;
    }
}