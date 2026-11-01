# Lesson 01 — Understand, run, test, and save a painting

> **Goal:** From browser brush strokes to a persistent SQL Server row, with no AWS expenses. Only Dev exists in this project.

### 1. Start the local database and API

Requirements: Docker Desktop/Engine and roughly 4–6 GiB free RAM; Docker SQL Server can take a few minutes to initialize. The local SQL Server image is Developer Edition for learning, not an AWS production license.

```bash
cd paintstudio-app
cp .env.example .env
# edit .env with a new, strong password, not the sample value

docker compose up -d db
docker compose logs -f db    # exit with Ctrl+C when SQL Server is ready
docker compose build app
docker compose run --rm app --migrate
docker compose up -d app
curl -fsS http://localhost:8080/health/live
curl -fsS http://localhost:8080/health/ready
curl -fsS http://localhost:8080/api/paintings/
```

Open http://localhost:8080 and draw with the brush. Select a color; change brush width; erase; undo and redo; name your painting; save it; reopen it from the gallery; export PNG. To view application logs: `docker compose logs -f app`. Shutdown without data loss: `docker compose down`. **Permanent delete of local SQL data:** `docker compose down -v`.

### 2. Know the actual code flow

- `src/PaintStudio.Api/wwwroot/index.html`: the browser layout, canvas, buttons and gallery.
- `wwwroot/styles.css`: styling and responsive layout.
- `wwwroot/app.js`: pointer events, color picker, drawing state, PNG export, API HTTP calls.
- `Program.cs`: API routes, dependency injection, SQL connection setup, structured logging, Prometheus metrics, migrations mode, readiness/liveness.
- `Models/Painting.cs`: painting ID, title, PNG byte array and created timestamp; request/response DTOs.
- `Data/PaintDbContext.cs`: Entity Framework Core maps the Painting object to SQL `Paintings` table.
- `Migrations/`: versioned SQL schema creation; `--migrate` runs EF migrations **as a one-off job**, never automatically on every app pod.
- `Services/PngValidator.cs`: upload validation/limits to reduce accidental oversized or invalid uploads.
- `tests/PaintStudio.Tests/`: xUnit tests for the PNG validator.
- `Dockerfile`: .NET SDK restores and publishes; slim ASP.NET runtime hosts non-root process.
- `docker-compose.yml`: only for local application and SQL; not AWS infrastructure.
- `Jenkinsfile`: Gitleaks, Trivy, SonarQube quality gate, Nexus, Vault, immutable ECR image, GitOps handoff.

A save goes: Canvas → PNG data URL → `POST /api/paintings/` → validation → `PaintDbContext` → SQL INSERT → JSON metadata response → gallery image URL. On EKS, RDS passwords come through External Secrets Operator into env keys `PaintDb__User` and `PaintDb__Password`, never committed to Git.

### 3. Build and run tests

```bash
dotnet restore PaintStudio.slnx
dotnet build PaintStudio.slnx -c Release
dotnet test PaintStudio.slnx -c Release
```

Run API smoke checks:

```bash
curl -fsS http://localhost:8080/metrics | grep paintstudio
curl -fsS http://localhost:8080/api/paintings/
```

### 4. Follow the repository responsibilities

- Edit app source → App Git repo → Jenkins application pipeline.
- Edit Terraform module → Terraform modules repo → release module Git tag.
- Edit payload or resource composition → Infra live repo → Jenkins Terraform pipeline (plan, approval, apply).
- Edit K8s replicas, config or image → GitOps repo → Argo CD reconciles Dev cluster.

### 5. Common failures

- SQL container not ready: inspect `docker compose logs db` and rerun migration.
- SQL password policy error: choose a strong password with upper, lower, numbers, and punctuation.
- `/health/ready` returns 503: check DB connectivity, SQL credentials and migrations.
- Image pull fails on EKS: CI has not pushed the immutable image tag yet, or ECR/account/region is wrong.
- Argo PreSync migration pending: check `kubectl -n paintstudio-dev get job,pods,secret,configmap` and ESO ExternalSecret status.
- Metrics absent: verify `kubectl -n monitoring get servicemonitors` and Prometheus Targets screen.

### 6. Completion criteria

1. Local painting saved and loaded after container restart.
2. Tests pass, endpoints report healthy, Prometheus metric appears after save.
3. Four repositories initialized independently and first code commits pushed.
4. You can explain which job builds the container and which tool deploys it.

Continue with the complete Dev guide at `DEV_RUNBOOK.md` in the bundle root.
