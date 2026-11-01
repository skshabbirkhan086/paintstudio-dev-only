# NuGet restore security fix (November 1, 2026)

The earlier starter failed `docker compose build app` because NuGet audit found two vulnerabilities in transitive `System.Security.Cryptography.Pkcs` 9.0.4. With `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`, `NU1902`/`NU1903` correctly block the restore.

The updated `paintstudio-app/src/PaintStudio.Api/PaintStudio.Api.csproj` pins `System.Security.Cryptography.Pkcs` **10.0.14** (patched for both advisories), and updates `Microsoft.EntityFrameworkCore.SqlServer` and `Microsoft.EntityFrameworkCore.Design` to matching **10.0.14** patch versions. NuGet auditing and warnings-as-errors remain active.

Check on your computer:

```bash
cd paintstudio-dev-only/paintstudio-app
docker compose build --progress=plain app
docker compose run --rm app --migrate
docker compose up -d app
curl -f http://localhost:8080/health/live
```

If you only want to edit your existing copy, add this to the `<ItemGroup>` in `src/PaintStudio.Api/PaintStudio.Api.csproj`:

```xml
<PackageReference Include="System.Security.Cryptography.Pkcs" Version="10.0.14" />
```

When a .NET 10 SDK is available, inspect resolved dependencies with:

```bash
dotnet list src/PaintStudio.Api/PaintStudio.Api.csproj package --include-transitive --vulnerable
```

Security advisories: https://github.com/advisories/GHSA-846f-f764-76mx and https://github.com/advisories/GHSA-2fmv-rv2c-59x7

NOTE: This environment does not have `dotnet`/`docker` installed; the modified project XML and archive are validated, but compilation is not claimed.
