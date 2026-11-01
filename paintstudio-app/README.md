# PaintStudio application — .NET 10, Dev-only

A usable drawing editor (`wwwroot/app.js` with HTML5 Canvas) and ASP.NET Core 10 API, backed by SQL Server with EF Core migrations. The project supports color selection, brush size, eraser, undo, redo, save, gallery, delete and PNG export.

## Run locally

```bash
cp .env.example .env     # edit the SQL password, do not commit
docker compose up -d db
docker compose logs -f db   # Ctrl+C once ready
docker compose build app
docker compose run --rm app --migrate
docker compose up -d app
curl -fsS http://localhost:8080/health/ready
```

Open **http://localhost:8080**. Unit tests: `dotnet test PaintStudio.slnx -c Release`. The browser's save path is `POST /api/paintings/`, returning an image URL; API reads/writes the `Paintings` table in SQL Server. Prometheus metrics are at `/metrics`, liveness `/health/live`, readiness `/health/ready`.

Local Compose uses a development `ConnectionStrings__PaintDb`. In Dev EKS, `PaintDb__Server`, `PaintDb__User`, `PaintDb__Password` are injected by Kubernetes ConfigMap/ExternalSecret and combined securely with `SqlConnectionStringBuilder`, enabling TLS validation.

## Jenkins

App `Jenkinsfile`: Gitleaks → .NET restore/test → Trivy fs → SonarQube analysis and quality gate → Nexus artifact using Vault credentials → Docker and Trivy image scan → ECR push → update Dev GitOps SHA tag. `YOUR_ORG`, `REPLACE_ACCOUNT_ID`, Vault/Sonar/Nexus URLs, credential IDs and Jenkins plugins/agent tools must be configured before it will execute. Never run untrusted PR code on AWS privileged Docker agents. See bundle `DEV_RUNBOOK.md`.

**Security scope:** single-user learning app. No login/authorization; run only privately, not as a public multi-user app. Never use local Developer SQL Server Edition in a licensed commercial production service.
