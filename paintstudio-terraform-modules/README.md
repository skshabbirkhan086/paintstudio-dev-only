# Reusable Terraform modules for PaintStudio Dev

Versioned, isolated Git repo. Commit and tag `v0.1.0` before using the live repo. `modules/network` creates VPC/public/private subnets/single NAT. `modules/eks` creates EKS managed nodes plus OIDC provider for IRSA. `modules/ecr` creates an encrypted immutable repository. `modules/sqlserver` creates a private encrypted RDS SQL Server Express DB with AWS-managed master secret. `modules/opensearch` creates **optional** private encrypted OpenSearch (single data node is Dev-only). The modules are technically reusable but only **Dev is wired** in this exercise. `Jenkinsfile` tests Gitleaks, Checkov, Terraform format/validate.

**Important:** Module changes should create a new Git tag; update `?ref=` in the live repo and review the Terraform plan. Never repoint an existing published module tag to different infrastructure content.

Before committing the modules, run `terraform fmt -recursive` in this repository so Jenkins format checks pass.
