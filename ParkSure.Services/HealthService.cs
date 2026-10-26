using ParkSure.Repositories;

namespace ParkSure.Services;

public class HealthService
{
    private readonly StatsRepository _stats;
    public HealthService(StatsRepository stats) => _stats = stats;

    public async Task<object> CheckAsync(CancellationToken ct)
    {
        var counts = await _stats.CountRowsAsync(ct);
        return new { database = "ok", rows = counts };
    }
}