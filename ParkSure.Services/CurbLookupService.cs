using ParkSure.Models;
using ParkSure.Repositories;

namespace ParkSure .Services;

public class CurbLookupService
{
    public const double MaxDistanceM = 30.0;   // inclusive
    public const double TieMarginM = 2.0;      // inclusive, tap mode only
    public const string CoveredBorough = "MTL";

    private readonly CurbRepository _repo;
    public CurbLookupService(CurbRepository repo) => _repo = repo;

    public async Task<CurbLookupResult> LookupByPointAsync(
        double lat, double lon, PinMode mode, CancellationToken ct)
    {
        var near = await _repo.FindNearestAsync(lat, lon, ct);
        var within = near.Where(c => c.DistanceM <= MaxDistanceM).ToList();
        if (within.Count == 0)
            return new(LookupOutcome.NoCurb, [], []);

        var first = within[0];
        if (mode == PinMode.Tap)
        {
            var tied = within.Where(c => c.DistanceM - first.DistanceM <= TieMarginM).ToList();
            if (tied.Count > 1)
                return new(LookupOutcome.Ambiguous, tied, []);
        }
        return await BuildForCurbAsync(first, ct);
    }

    // Returns null when the segment id does not exist.
    public async Task<CurbLookupResult?> LookupBySegmentAsync(int segmentId, CancellationToken ct)
    {
        var curb = await _repo.GetCurbAsync(segmentId, ct);
        return curb is null ? null : await BuildForCurbAsync(curb, ct);
    }

    private async Task<CurbLookupResult> BuildForCurbAsync(CurbCandidate curb, CancellationToken ct)
    {
        // Area check comes BEFORE the sign check (locked in piece 2).
        if (curb.Borough != CoveredBorough)
            return new(LookupOutcome.NoDataArea, [curb], []);

        var signs = await _repo.GetActiveSignsAsync(curb.SegmentId, ct);
        return signs.Count == 0
            ? new(LookupOutcome.NoSigns, [curb], [])
            : new(LookupOutcome.Found, [curb], signs);
    }
}