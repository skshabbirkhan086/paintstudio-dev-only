using Microsoft.EntityFrameworkCore;
using PaintStudio.Api.Models;

namespace PaintStudio.Api.Data;

public sealed class PaintDbContext(DbContextOptions<PaintDbContext> options) : DbContext(options)
{
    public DbSet<Painting> Paintings => Set<Painting>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var item = modelBuilder.Entity<Painting>();
        item.ToTable("Paintings");
        item.HasKey(p => p.Id);
        item.Property(p => p.Name).HasMaxLength(100).IsRequired();
        item.Property(p => p.PngData).HasColumnType("varbinary(max)").IsRequired();
        item.Property(p => p.CreatedUtc).HasColumnType("datetime2").IsRequired();
        item.HasIndex(p => p.CreatedUtc);
    }
}
