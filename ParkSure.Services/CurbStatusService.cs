using ParkSure.Evaluation;
using ParkSure.Models;
using ParkSure.Repositories;
using Microsoft.Extensions.Logging;
namespace ParkSure.Services;

public sealed record CurbStatusResponse(
    string Outcome,                              // "evaluated" or "ambiguous"
    IReadOnlyList<CurbCandidate> Curbs,
    EvaluationResult? Evaluation,
    IReadOnlyList<CurbSign> Signs);

/// <summary>Single-curb query: find the curb (B2), load its rules, evaluate (B3), log unknowns.</summary>
public class CurbStatusService
{
    private const int LogDecimals = 3;           // about 100 m: the log never keeps an exact GPS position

    private readonly CurbLookupService _lookup;
    private readonly RuleRepository _rules;
    private readonly UnknownLogRepository _log;
    private readonly CurbEvaluator _evaluator;
    private readonly ILogger<CurbStatusService> _logger;

    public CurbStatusService(CurbLookupService lookup, RuleRepository rules,
        UnknownLogRepository log, CurbEvaluator evaluator, ILogger<CurbStatusService> logger)
    {
        _lookup = lookup; _rules = rules; _log = log; _evaluator = evaluator; _logger = logger;
    }

    /// <summary>Returns null when segmentId is given and does not exist.</summary>
    public async Task<CurbStatusResponse?> GetAsync(
        double lat, double lon, PinMode mode, int? segmentId,
        DateTimeOffset at, string? permit, CancellationToken ct)
    {
        var lookup = segmentId is int id
            ? await _lookup.LookupBySegmentAsync(id, ct)
            : await _lookup.LookupByPointAsync(lat, lon, mode, ct);
        if (lookup is null) return null;

        // Two sides within 2 m: the app asks the user to pick one. Nothing is evaluated or logged.
        if (lookup.Outcome == LookupOutcome.Ambiguous)
            return new CurbStatusResponse("ambiguous", lookup.Curbs, null, []);

        var context = await BuildContextAsync(lookup, ct);
        var result = _evaluator.Evaluate(context, at, permit);

        if (result.Status == CurbStatus.Unknown)
            await TryLogAsync(result, lookup.Curbs, lat, lon, ct);

        return new CurbStatusResponse("evaluated", lookup.Curbs, result, lookup.Signs);
    }

    private async Task<CurbContext> BuildContextAsync(CurbLookupResult lookup, CancellationToken ct)
    {
        switch (lookup.Outcome)
        {
            case LookupOutcome.NoCurb: return new CurbContext(false, true, []);
            case LookupOutcome.NoDataArea: return new CurbContext(true, false, []);
            case LookupOutcome.NoSigns: return new CurbContext(true, true, []);
        }

        var codes = lookup.Signs.Select(s => s.CodeRpa).Distinct(StringComparer.Ordinal).ToList();
        var rows = await _rules.GetByCodesAsync(codes, ct);

        // A row that is unreviewed, unreadable or of an unknown type becomes "no usable rule" (null).
        var parsed = new Dictionary<string, ParkingRule?>(StringComparer.Ordinal);
        foreach (var row in rows)
            parsed[row.Code] = RuleParser.TryParse(row.Code, row.RuleType, row.Priority, row.Reviewed,
                row.WindowsJson, row.PermitSector, row.MaxMinutes, out _);

        var signs = lookup.Signs
            .Select(s => new LinkedSign(s.SignId, s.CodeRpa, s.Confidence, parsed.GetValueOrDefault(s.CodeRpa)))
            .ToList();
        return new CurbContext(true, true, signs);
    }

    // The log must never break an answer: a failed write is reported and the request carries on.
    private async Task TryLogAsync(EvaluationResult result, IReadOnlyList<CurbCandidate> curbs,
        double lat, double lon, CancellationToken ct)
    {
        try
        {
            var now = DateTime.UtcNow;
            var latLog = Math.Round((decimal)lat, LogDecimals);
            var lonLog = Math.Round((decimal)lon, LogDecimals);
            int? segmentId = curbs.Count > 0 ? curbs[0].SegmentId : null;
            var reason = ReasonName(result.UnknownReason!.Value);

            // One row per distinct missing code; any other reason gets a single row.
            var rows = result.UnknownReason == UnknownReason.NoRule && result.MissingCodes.Count > 0
                ? result.MissingCodes.Select(c => new UnknownLogEntry(now, latLog, lonLog, segmentId, reason, c)).ToList()
                : new List<UnknownLogEntry> { new(now, latLog, lonLog, segmentId, reason, null) };

            await _log.InsertAsync(rows, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogWarning(ex, "unknown_log write failed");
        }
    }

    public static string ReasonName(UnknownReason r) => r switch
    {
        UnknownReason.NoCurb => "no_curb",
        UnknownReason.NoDataArea => "no_data_area",
        UnknownReason.NoSigns => "no_signs",
        UnknownReason.LowConfidence => "low_confidence",
        UnknownReason.NoRule => "no_rule",
        _ => "unknown"
    };
}
