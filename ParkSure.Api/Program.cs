using Npgsql;
using ParkSure.Evaluation;
using ParkSure.Repositories;
using ParkSure.Services;

var builder = WebApplication.CreateBuilder(args);

// Configuration & Database
var cs = builder.Configuration.GetConnectionString("Default")
         ?? throw new InvalidOperationException("Connection string 'Default' is missing");

builder.Services.AddSingleton(NpgsqlDataSource.Create(cs));

// Stateless Evaluation Engine
builder.Services.AddSingleton(new CurbEvaluator());

// Repositories
builder.Services.AddScoped<StatsRepository>();
builder.Services.AddScoped<CurbRepository>();
builder.Services.AddScoped<RuleRepository>();
builder.Services.AddScoped<UnknownLogRepository>();

// Services
builder.Services.AddScoped<HealthService>();
builder.Services.AddScoped<CurbLookupService>();
builder.Services.AddScoped<CurbStatusService>();
builder.Services.AddSingleton<RuleCatalog>();        // parsed rules kept in memory, refreshed every 5 minutes
builder.Services.AddScoped<CurbMapRepository>();
builder.Services.AddScoped<CurbMapService>();

// ---- optional but recommended on mobile data: compress the map responses (about 5x smaller) ----
builder.Services.AddResponseCompression();
// Web API & OpenAPI
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Development only: let the Flutter web app (served from another localhost
// port) call the API. Production CORS is decided when the app is deployed.
const string DevCors = "DevLocalhost";
builder.Services.AddCors(o => o.AddPolicy(DevCors, p => p
    .SetIsOriginAllowed(origin => Uri.TryCreate(origin, UriKind.Absolute, out var uri) && uri.IsLoopback)
    .WithMethods("GET")
    .AllowAnyHeader()));

var app = builder.Build();
app.UseResponseCompression();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();                       // serves /openapi/v1.json
    app.UseSwaggerUI(o =>                    // UI at /swagger
    {
        o.SwaggerEndpoint("/openapi/v1.json", "ParkSure API v1");
    });
    app.UseCors(DevCors);
}

app.UseAuthorization();

app.MapControllers();

app.Run();