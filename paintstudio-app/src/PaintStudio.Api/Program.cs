using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using PaintStudio.Api.Data;
using PaintStudio.Api.Models;
using PaintStudio.Api.Services;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole();
// Local Docker Compose accepts a connection string. On EKS, use individual keys from
// External Secrets (special characters in RDS-generated passwords are escaped safely).
var connection = builder.Configuration.GetConnectionString("PaintDb");
if (string.IsNullOrWhiteSpace(connection))
{
    var host = builder.Configuration["PaintDb:Server"];
    var username = builder.Configuration["PaintDb:User"];
    var password = builder.Configuration["PaintDb:Password"];
    if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(username) || string.IsNullOrEmpty(password))
        throw new InvalidOperationException("Configure ConnectionStrings:PaintDb or PaintDb:Server/User/Password.");
    connection = new SqlConnectionStringBuilder
    {
        DataSource = $"{host},1433",
        InitialCatalog = "PaintStudio",
        UserID = username,
        Password = password,
        Encrypt = SqlConnectionEncryptOption.Mandatory,
        TrustServerCertificate = false,
        ConnectTimeout = 15
    }.ConnectionString;
}
builder.Services.AddDbContext<PaintDbContext>(options => options.UseSqlServer(connection));
builder.Services.AddHealthChecks();

var app = builder.Build();

// Dedicated, explicit migration mode used by an admin job (never at pod startup).
if (args.Contains("--migrate", StringComparer.OrdinalIgnoreCase))
{
    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<PaintDbContext>();
    await db.Database.MigrateAsync();
    app.Logger.LogInformation("SQL Server database migration completed");
    return;
}

var created = Metrics.CreateCounter("paintstudio_paintings_created_total", "Paintings successfully saved");
var deleted = Metrics.CreateCounter("paintstudio_paintings_deleted_total", "Paintings successfully deleted");

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseHttpMetrics();

app.MapHealthChecks("/health/live");
app.MapGet("/health/ready", async Task<IResult> (PaintDbContext db, CancellationToken token) =>
{
    if (await db.Database.CanConnectAsync(token)) return Results.Ok(new { status = "ready" });
    return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
});
app.MapMetrics("/metrics");

var api = app.MapGroup("/api/paintings");
api.MapGet("/", async (PaintDbContext db, CancellationToken token) =>
    await db.Paintings.AsNoTracking()
        .OrderByDescending(p => p.CreatedUtc)
        .Take(100)
        .Select(p => new PaintingSummary(p.Id, p.Name, p.CreatedUtc, $"/api/paintings/{p.Id}/image"))
        .ToListAsync(token));

api.MapGet("/{id:guid}/image", async (Guid id, PaintDbContext db, CancellationToken token) =>
{
    var data = await db.Paintings.AsNoTracking().Where(x => x.Id == id)
        .Select(x => x.PngData).FirstOrDefaultAsync(token);
    return data is null ? Results.NotFound() : Results.File(data, "image/png");
});

api.MapPost("/", async (SavePaintingRequest request, PaintDbContext db, ILogger<Program> logger, CancellationToken token) =>
{
    var name = request.Name?.Trim();
    if (string.IsNullOrWhiteSpace(name) || name.Length > 100)
        return Results.BadRequest(new { error = "A painting name (1-100 characters) is required." });
    if (!PngValidator.TryDecode(request.DataUrl, out var image, out var error))
        return Results.BadRequest(new { error });

    var painting = new Painting { Name = name, PngData = image };
    db.Paintings.Add(painting);
    await db.SaveChangesAsync(token);
    created.Inc();
    logger.LogInformation("Painting saved {PaintingId} with {Bytes} bytes", painting.Id, image.Length);
    return Results.Created($"/api/paintings/{painting.Id}/image",
        new PaintingSummary(painting.Id, painting.Name, painting.CreatedUtc, $"/api/paintings/{painting.Id}/image"));
});

api.MapDelete("/{id:guid}", async (Guid id, PaintDbContext db, ILogger<Program> logger, CancellationToken token) =>
{
    var deletedCount = await db.Paintings.Where(p => p.Id == id).ExecuteDeleteAsync(token);
    if (deletedCount == 0) return Results.NotFound();
    deleted.Inc();
    logger.LogInformation("Painting deleted {PaintingId}", id);
    return Results.NoContent();
});

app.Run();

public partial class Program { } // Enables future WebApplicationFactory integration tests.
