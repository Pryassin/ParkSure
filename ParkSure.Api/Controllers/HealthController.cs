using Microsoft.AspNetCore.Mvc;
using Npgsql;
using ParkSure.Services;

namespace ParkSure.Controllers;

[ApiController]
[Route("api/health")]
public class HealthController : ControllerBase
{
    private readonly HealthService _health;
    public HealthController(HealthService health) => _health = health;

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        try { return Ok(await _health.CheckAsync(ct)); }
        catch (NpgsqlException) { return StatusCode(503, new { database = "unreachable" }); }
    }
}