# PaintStudio Dev architecture

```text
Developer --push--> GitHub: paintstudio-app
       |                  |
       |             Jenkins CI (main branch)
       |           Gitleaks -> dotnet test -> Trivy -> SonarQube / quality gate
       |              -> Nexus .tar.gz -> Docker -> Trivy image -> ECR
       |                                         |
       |                         write image SHA into GitOps/dev overlay
       |                                         |
       |                                    Argo CD
       |                                         |
       +---- GitHub infra-live -> Jenkins IaC --> Terraform --> AWS Dev
                                          Gitleaks/Checkov/TFLint/plan/APPROVAL

AWS Dev (ap-south-1):
  VPC 3 AZ; public subnets for a single NAT; private subnets for
  EKS managed worker nodes and RDS SQL Server Express.
  EKS paintstudio-dev  <- ECR immutable SHA-tagged container image
     | paintstudio-dev namespace
     | ASP.NET Core Pod --TCP 1433--> RDS SQL Server (private)
     | External Secrets Operator --IAM IRSA--> AWS Secrets Manager
     | Prometheus ServiceMonitor -> Grafana -> Alertmanager -> Slack
     | Fluent Bit (optional) --IRSA--> OpenSearch in VPC

Vault -> Jenkins credentials for Nexus; SonarQube checks .NET code;
Terraform modules versioned independently in their own Git repository.
```

## Source control / isolation

Four distinct repositories; single `dev` environment. The modules repo is pinned at `v0.1.0`, so module changes are reviewed and retagged deliberately. No QA/Production manifests in the bundle. Jenkins Terraform apply requires opt-in `APPLY_DEV=true` and human confirmation on a protected main branch. App CI publishes only from `main`; GitOps is a separate desired-state repository with Argo CD pulling from it.

## Secrets and bootstrap

Terraform enables RDS `manage_master_user_password`, causing AWS to manage the master login in Secrets Manager. Terraform outputs **only the secret ARN**, not the password. The External Secrets Operator IAM role is limited to reading the RDS secret. The `bootstrap-dev-secrets.sh` script installs a namespace-local SecretStore + ExternalSecret and a public (non-secret) DB-host ConfigMap. The resulting K8s Secret contains `username`/`password`; an ASP.NET SqlConnectionStringBuilder assembles the connection string with TLS enabled. For local development, Docker Compose uses a throwaway Developer-edition SQL Server with different credentials.

## Cost boundaries / gaps

Single NAT in 3-AZ Dev is a low-cost learning compromise; it is **not highly available** and can incur inter-AZ traffic. RDS Single-AZ, SQL Express and one managed node group are deliberately Dev-only. There is no public ALB/Ingress; use `kubectl port-forward` and add ingress and user authentication later. OpenSearch is OFF by default. When enabled, you must configure IAM principal mappings for fine-grained access control before Fluent Bit will ingest, even if IAM policies allow signed requests. Existing state files can expose resource metadata: restrict the S3 state bucket IAM permissions.
