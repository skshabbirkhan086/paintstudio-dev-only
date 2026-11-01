namespace PaintStudio.Api.Models;

public sealed class Painting
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Name { get; set; }
    public required byte[] PngData { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;
}

public sealed record SavePaintingRequest(string? Name, string? DataUrl);
public sealed record PaintingSummary(Guid Id, string Name, DateTime CreatedUtc, string ImageUrl);
