# PaintStudio Terraform live — DEV ONLY

- `payloads/dev.json` is the **only accepted** input. All environment configuration lives here.
- `main.tf` combines versioned remote Terraform modules from the separate `paintstudio-terraform-modules` Git repository.
- `iam.tf` creates IRSA roles for External Secrets Operator and optional Fluent Bit logging.
- `bootstrap-state/` creates a separate versioned S3 state bucket. Its local state must be kept safe.
- `backends/dev.hcl` holds the generated S3 bucket state configuration (`use_lockfile=true`).
- `Jenkinsfile` runs Checkov, TFLint, Gitleaks and a Dev-only Terraform plan; apply requires `APPLY_DEV=true` and manual approval on protected `main`.
- `scripts/setup-state.sh` bootstraps the state bucket; `scripts/plan-dev.sh` prepares Dev infrastructure for review.

**Required order:** push and tag modules as `v0.1.0`; run root `scripts/configure-dev.py` to replace account/org/CIDR; bootstrap state bucket; init/plan/apply. See bundle root `DEV_RUNBOOK.md`.
