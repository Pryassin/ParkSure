using ParkSure.Evaluation;
using ParkSure.Models;
using ParkSure.Repositories;

namespace ParkSure.Services;

public sealed record MapFeature(int SegmentId, string Side, string GeoJson,
                                CurbStatus Status, string Reason, DateTimeOffset? ValidUntil);

public sealed record MapResult(IReadOnlyList<MapFeature> Features, bool Truncated);

/// <summary>Colors every curb in view. Same evaluator as /api/curbs/at, so the map and the popup always agree.</summary>
public class CurbMapService
{
    public const int MaxFeatures = 5000;

    private readonly CurbMapRepository _repo;
    private readonly RuleCatalog _catalog;
    private readonly CurbEvaluator _evaluator;

    public CurbMapService(CurbMapRepository repo, RuleCatalog catalog, CurbEvaluator evaluator)
    { _repo = repo; _catalog = catalog; _evaluator = evaluator; }

    public async Task<MapResult> GetAsync(BoundingBox box, DateTimeOffset at, string? permit, CancellationToken ct)
    {
        var rows = await _repo.GetCurbsInBoxAsync(box, MaxFeatures + 1, ct);
        bool truncated = rows.Count > MaxFeatures;
        if (truncated) rows = rows.Take(MaxFeatures).ToList();

        var rules = await _catalog.GetAsync(ct);
        return new MapResult(EvaluateRows(rows, rules, _evaluator, at, permit), truncated);
    }

    /// <summary>
    /// Pure and testable. Thousands of curbs share a handful of distinct rule sets (for example "SD-TT" alone),
    /// and the answer depends only on that set and the time, so each distinct set is evaluated once per request.
    /// Unknown cases (no signs, shaky link, missing rule) are cheap and always go through the evaluator itself.
    /// </summary>
    public static List<MapFeature> EvaluateRows(
        IReadOnlyList<MapCurbRow> rows, IReadOnlyDictionary<string, ParkingRule?> rules,
        CurbEvaluator evaluator, DateTimeOffset at, string? permit)
    {
        var memo = new Dictionary<string, EvaluationResult>(StringComparer.Ordinal);
        var features = new List<MapFeature>(rows.Count);

        foreach (var row in rows)
        {
            var codes = row.Codes ?? Array.Empty<string>();
            // Any sign below the threshold means the minimum is below it, so the minimum stands in for every sign.
            decimal confidence = row.MinConfidence ?? 0m;
            var signs = codes.Select((c, i) => new LinkedSign(i + 1, c, confidence, rules.GetValueOrDefault(c))).ToList();
            var context = new CurbContext(true, true, signs);

            bool usable = signs.Count > 0 && confidence >= CurbEvaluator.MinConfidence && signs.All(s => s.Rule is not null);
            EvaluationResult result;
            if (!usable)
                result = evaluator.Evaluate(context, at, permit);
            else
            {
                var key = string.Join('|', codes);
                if (!memo.TryGetValue(key, out result!))
                    memo[key] = result = evaluator.Evaluate(context, at, permit);
            }
            features.Add(new MapFeature(row.SegmentId, row.Side, row.GeoJson, result.Status, result.Reason, result.ValidUntil));
        }
        return features;
    }
}
