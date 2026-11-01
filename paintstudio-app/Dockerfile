FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source
COPY src/PaintStudio.Api/PaintStudio.Api.csproj src/PaintStudio.Api/
RUN dotnet restore src/PaintStudio.Api/PaintStudio.Api.csproj
COPY src/PaintStudio.Api/ src/PaintStudio.Api/
RUN dotnet publish src/PaintStudio.Api/PaintStudio.Api.csproj -c Release --no-restore -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "PaintStudio.Api.dll"]
