using Npgsql;

namespace ParkSure.Repositories;

/// <summary>One row of parking_rule exactly as stored. RuleParser decides whether it is usable.</summary>
public sealed record RuleRow(string Code, string? RuleType, int Priority, bool Reviewed,
                             string? WindowsJson, string? PermitSector, int? MaxMinutes);

public class RuleRepository
{
    private readonly NpgsqlDataSource _db;
    public RuleRepository(NpgsqlDataSource db) => _db = db;

    // ASSUMED column names: code_rpa, rule_type, priority, reviewed, windows, permit_sector, max_duration_minutes.
    private const string Columns =
        "code_rpa, rule_type, priority, reviewed, windows::text, permit_sector, max_duration_minutes";

    public Task<List<RuleRow>> GetAllAsync(CancellationToken ct) =>
        ReadAsync($"SELECT {Columns} FROM parking_rule ORDER BY code_rpa", null, ct);

    public Task<List<RuleRow>> GetByCodesAsync(IReadOnlyCollection<string> codes, CancellationToken ct) =>
        codes.Count == 0
            ? Task.FromResult(new List<RuleRow>())
            : ReadAsync($"SELECT {Columns} FROM parking_rule WHERE code_rpa = ANY(@codes)", codes.ToArray(), ct);

    private async Task<List<RuleRow>> ReadAsync(string sql, string[]? codes, CancellationToken ct)
    {
        await using var cmd = _db.CreateCommand(sql);
        if (codes is not null) cmd.Parameters.AddWithValue("codes", codes);
        var list = new List<RuleRow>();
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            list.Add(new RuleRow(
                r.GetString(0),
                r.IsDBNull(1) ? null : r.GetString(1),
                r.IsDBNull(2) ? 100 : r.GetInt32(2),
                !r.IsDBNull(3) && r.GetBoolean(3),
                r.IsDBNull(4) ? null : r.GetString(4),
                r.IsDBNull(5) ? null : r.GetString(5),
                r.IsDBNull(6) ? null : r.GetInt32(6)));
        return list;
    }
}
