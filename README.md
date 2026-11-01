# PaintStudio | Dev-only, realistic .NET 10 + AWS EKS DevSecOps lab

**Scope: ONE environment (`dev`) only.** This bundle holds four separate Git repos plus a few setup scripts. There are **no QA or Production payloads, overlays, or Terraform pipelines** in this package.

## What you'll deploy

Web painting editor (Canvas + JavaScript) → ASP.NET Core 10 API → RDS SQL Server Express, running in **EKS (Dev, ap-south-1)**. Git/Jenkins builds + scans + pushes SHA-tagged images to ECR and updates the **Dev** GitOps overlay. Argo CD syncs the new version. Prometheus/Grafana collect metrics; Slack receives alerts. AWS OpenSearch/Fluent Bit is available as a **second, explicit paid phase**, off by default.

| Repo folder (create a separate GitHub repository for each) | Responsibility |
| --- | --- |
| `paintstudio-app` | .NET solution, UI, SQL migrations, tests, Docker, Jenkins build pipeline |
| `paintstudio-terraform-modules` | Reusable Git-versioned Terraform modules for VPC/EKS/ECR/RDS/OpenSearch |
| `paintstudio-infra-live` | Single Dev JSON payload, S3 state bootstrap, AWS resources, IAM, Terraform Jenkins pipeline |
| `paintstudio-gitops` | Dev Kubernetes manifests, Argo Application, monitoring, secret bootstrap, logging |

Extra root folders: `scripts/` for one-time AWS account/Git config; `ci-tools/` for local experiments with Jenkins-related services.

## Deployment in stages

0. Read [DEV_RUNBOOK.md](DEV_RUNBOOK.md), including estimated AWS charges, IAM access, and safety notes. Prerequisites: Git, AWS CLI v2, Terraform >=1.10, kubectl, Helm 3, Docker, .NET 10 SDK (or Docker for local app).
1. **Local application:** follow [LESSON_01.md](LESSON_01.md). `cd paintstudio-app`; `cp .env.example .env`; set a strong SQL password; `docker compose up -d db`; wait for SQL; `docker compose build app`; `docker compose run --rm app --migrate`; `docker compose up -d app`; visit http://localhost:8080.
2. **Git:** create four GitHub repos. Push `paintstudio-terraform-modules` first and create Git tag `v0.1.0`, since the live repo uses this remote module source. Push other repos after configuration.
3. **Configuration:** from bundle root run `python3 scripts/configure-dev.py YOUR_GITHUB_ORG YOUR_PUBLIC_IPV4/32` (gets Dev AWS account via `aws sts get-caller-identity`). Review the diff; **no account secret is written to Git**.
4. **Terraform state:** `cd paintstudio-infra-live && bash scripts/setup-state.sh` (creates versioned S3 state bucket). Then `bash scripts/plan-dev.sh`, inspect `dev-plan.txt`, then `terraform apply dev.tfplan` **only when ready**.
5. **EKS & secrets:** `aws eks update-kubeconfig --region ap-south-1 --name paintstudio-dev`; install External Secrets Operator with `paintstudio-gitops/scripts/install-eso-dev.sh`, then call `paintstudio-gitops/scripts/bootstrap-dev-secrets.sh` after Terraform is initialized (absolute paths or run from bundle root).
6. **First image:** configure CI or manually build/push an image to ECR, replace overlay `newTag: bootstrap` with the real image SHA tag. Apply `paintstudio-gitops/applications/dev.yaml` to Argo CD once Argo CD is installed. The PreSync database migration Job runs first.
7. **Metrics & notifications:** deploy kube-prometheus-stack and Slack secret as described in the runbook; use `paintstudio-gitops/scripts/install-monitoring-dev.sh`.
8. **Optional logging:** after the app works, set `payloads/dev.json` `opensearch.enabled=true`, fill the OpenSearch admin IAM ARN, review cost and Terraform plan/apply, configure fine-grained role mapping, and run `paintstudio-gitops/scripts/install-logging-dev.sh`.

**No resources are deployed merely by downloading this ZIP.** This is a project source package, not a claim that AWS resources or integrations were provisioned.

### Important limitations

This is a **hands-on lab**, not a hardened public internet SaaS. It has no user login or ownership authorization, and may expose other users' paintings; use port-forward or private access only. Jenkins, SonarQube, Nexus and Vault need installation, credentials and networking per [DEV_RUNBOOK.md](DEV_RUNBOOK.md). Use a disposable training AWS account; Terraform EKS/RDS/NAT/OpenSearch are billable until destroyed. No promises of zero cost.
