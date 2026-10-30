using Microsoft.Extensions.DependencyInjection;
using ParkSure.Evaluation;
using ParkSure.Repositories;

namespace ParkSure.Services;

/// <summary>
/// All parsed rules, kept in memory (about 200 rows) and refreshed every few minutes, so a map request never
/// reads parking_rule. A code that is missing, unreviewed, unreadable or of an unknown type maps to null.
/// </summary>
public sealed class RuleCatalog
{
    private static readonly TimeSpan Ttl = TimeSpan.FromMinutes(5);
    private sealed record Snapshot(IReadOnlyDictionary<string, ParkingRule?> Rules, DateTime LoadedAtUtc);

    private readonly IServiceScopeFactory _scopes;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private volatile Snapshot? _snapshot;

    public RuleCatalog(IServiceScopeFactory scopes) => _scopes = scopes;

    public async Task<IReadOnlyDictionary<string, ParkingRule?>> GetAsync(CancellationToken ct)
    {
        var current = _snapshot;
        if (current is not null && DateTime.UtcNow - current.LoadedAtUtc < Ttl) return current.Rules;

        await _gate.WaitAsync(ct);
        try
        {
            current = _snapshot;
            if (current is not null && DateTime.UtcNow - current.LoadedAtUtc < Ttl) return current.Rules;

            using var scope = _scopes.CreateScope();
            var repo = scope.ServiceProvider.GetRequiredService<RuleRepository>();
            var map = new Dictionary<string, ParkingRule?>(StringComparer.Ordinal);
            foreach (var row in await repo.GetAllAsync(ct))
                map[row.Code] = RuleParser.TryParse(row.Code, row.RuleType, row.Priority, row.Reviewed,
                    row.WindowsJson, row.PermitSector, row.MaxMinutes, out _);

            _snapshot = new Snapshot(map, DateTime.UtcNow);
            return map;
        }
        finally { _gate.Release(); }
    }

    /// <summary>Call after loading new rules if you do not want to wait for the refresh.</summary>
    public void Invalidate() => _snapshot = null;
}
