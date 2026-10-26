using Npgsql;
using ParkSure.Repositories;
using ParkSure.Services;

var builder = WebApplication.CreateBuilder(args);

var cs = builder.Configuration.GetConnectionString("Default")
         ?? throw new InvalidOperationException("Connection string 'Default' is missing");

builder.Services.AddSingleton(NpgsqlDataSource.Create(cs));
builder.Services.AddScoped<StatsRepository>();
builder.Services.AddScoped<HealthService>();
builder.Services.AddScoped<CurbRepository>();
builder.Services.AddScoped<CurbLookupService>();

builder.Services.AddControllers();
builder.Services.AddOpenApi();


var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseAuthorization();
app.MapControllers();

app.Run();