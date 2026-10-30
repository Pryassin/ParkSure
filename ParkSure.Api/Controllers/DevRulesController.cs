using Microsoft.AspNetCore.Mvc;
using ParkSure.Evaluation;
using ParkSure.Repositories;

namespace ParkSure.Controllers;

/// <summary>Development only: checks every stored rule against the real parser (the "separate data check").</summary>
[ApiController]
[Route("api/dev")]
public class DevRulesController : ControllerBase
{
    private readonly RuleRepository _rules;
    private readonly IWebHostEnvironment _env;
    public DevRulesController(RuleRepository rules, IWebHostEnvironment env) { _rules = rules; _env = env; }

    [HttpGet("rule-check")]
    public async Task<IActionResult> RuleCheck(CancellationToken ct)
    {
        if (!_env.IsDevelopment()) return NotFound();

        var rows = await _rules.GetAllAsync(ct);
        var rejected = new List<object>();
        int parsed = 0;
        foreach (var row in rows)
        {
            var rule = RuleParser.TryParse(row.Code, row.RuleType, row.Priority, row.Reviewed,
                row.WindowsJson, row.PermitSector, row.MaxMinutes, out var problem);
            if (rule is null) rejected.Add(new { code = row.Code, ruleType = row.RuleType, problem });
            else parsed++;
        }
        var ruleTypes = rows.GroupBy(r => r.RuleType ?? "(null)")
                            .OrderByDescending(g => g.Count())
                            .ToDictionary(g => g.Key, g => g.Count());
        return Ok(new { total = rows.Count, parsed, rejectedCount = rejected.Count, rejected, ruleTypes });
    }
}
