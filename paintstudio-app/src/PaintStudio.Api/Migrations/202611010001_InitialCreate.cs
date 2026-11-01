using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using PaintStudio.Api.Data;

#nullable disable

namespace PaintStudio.Api.Migrations;

[DbContext(typeof(PaintDbContext))]
[Migration("202611010001_InitialCreate")]
public sealed class InitialCreate : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Paintings",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                PngData = table.Column<byte[]>(type: "varbinary(max)", nullable: false),
                CreatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_Paintings", x => x.Id));
        migrationBuilder.CreateIndex(name: "IX_Paintings_CreatedUtc", table: "Paintings", column: "CreatedUtc");
    }

    protected override void Down(MigrationBuilder migrationBuilder) => migrationBuilder.DropTable(name: "Paintings");
}
