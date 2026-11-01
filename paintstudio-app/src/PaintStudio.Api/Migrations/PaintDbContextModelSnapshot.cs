using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using PaintStudio.Api.Data;

#nullable disable
namespace PaintStudio.Api.Migrations;

[DbContext(typeof(PaintDbContext))]
public sealed class PaintDbContextModelSnapshot : ModelSnapshot
{
    protected override void BuildModel(ModelBuilder modelBuilder)
    {
        modelBuilder.HasAnnotation("ProductVersion", "10.0.0");
        modelBuilder.Entity("PaintStudio.Api.Models.Painting", b =>
        {
            b.Property<Guid>("Id").ValueGeneratedOnAdd().HasColumnType("uniqueidentifier");
            b.Property<DateTime>("CreatedUtc").HasColumnType("datetime2");
            b.Property<string>("Name").IsRequired().HasMaxLength(100).HasColumnType("nvarchar(100)");
            b.Property<byte[]>("PngData").IsRequired().HasColumnType("varbinary(max)");
            b.HasKey("Id");
            b.HasIndex("CreatedUtc");
            b.ToTable("Paintings");
        });
    }
}
