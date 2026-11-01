# Dev-only deployment runbook: hands-on in the correct order

All examples target **ap-south-1**, AWS account returned by your AWS CLI, EKS cluster **paintstudio-dev**, and Kubernetes namespace **paintstudio-dev**. Nothing in this package creates QA/Production.

## Prerequisites and safety

- Disposable AWS account, permissions sufficient for IAM/EKS/VPC/EC2/RDS/KMS/ECR/OpenSearch/S3/Secrets Manager. Configure an AWS profile and confirm `aws sts get-caller-identity` before creating ANY resources.
- Linux/WSL2 terminal with `git`, `aws` CLI v2, Terraform >=1.10, `kubectl`, Helm 3, Docker and Python 3. GitHub repo permissions. For app-only local work, Docker is sufficient.
- **Ongoing charges**: EKS control plane, 2x EC2 worker nodes, NAT Gateway + data processing, RDS SQL Server licensing/storage and, when enabled, OpenSearch, plus monitoring/storage and CI agents. This is **not** a free-tier lab. Review the AWS Pricing Calculator and budgets. Enable AWS Budget alerts. A single NAT is economical but not fault-tolerant.
- Use **port forwarding and private network only** until login, ownership, rate limits and security review exist. No public ingress supplied. Private RDS endpoint not directly accessible from laptop without VPN/bastion/SSM tunnel.
- Never store `.env`, passwords, Slack webhook or IAM access keys in Git. S3 Terraform state must be tightly IAM-restricted; protect the Dev state bucket.

## Phase A — app locally and 4 distinct repos

Follow `LESSON_01.md`; then create GitHub repos named:

1. `paintstudio-terraform-modules`
2. `paintstudio-infra-live`
3. `paintstudio-app`
4. `paintstudio-gitops`

From each subfolder, run:

```bash
git init -b main
git add .
git commit -m "Initial PaintStudio Dev project"
git remote add origin git@github.com:YOUR_ORG/REPO_NAME.git
git push -u origin main
```

For `paintstudio-terraform-modules` specifically, after push:

```bash
git tag v0.1.0
git push origin v0.1.0
```

**Correct order:** configure your organization/account and EKS CIDR **before** committing the Dev repos, or commit a follow-up config change. Set module references in `paintstudio-infra-live/main.tf` to your actual module repo if you use a different Git host. Tag the modules repo **after** final module edits, so `v0.1.0` resolves the expected content. For private Git modules, Terraform/Jenkins must have read access to Git. For initial learning, a public repo without secrets is simpler.

## Phase B — configure AWS and Dev payload

```bash
aws sts get-caller-identity
aws configure list
# From bundle root; change IP to YOUR real public IP/32.
python3 scripts/configure-dev.py YOUR_GITHUB_ORG 198.51.100.25/32
```

The `/32` shown above is an **example-only documentation IP**; do not use it literally. Determine your current public IPv4 via `curl -4 ifconfig.me` (or the IP your VPN exits from). If you use WSL behind VPN, ensure network routing reaches EKS public API endpoint. Review `paintstudio-infra-live/payloads/dev.json`: VPC network, 3 AZs, two `t3.large` nodes, `sqlserver-ex` Single-AZ, OpenSearch off.

`paintstudio-infra-live/main.tf` pulls **Git-versioned modules**, which Terraform downloads on `terraform init`. The JSON payload is parsed with `jsondecode(file(...))`. Therefore the modules tag must already exist before live Terraform `init`.

## Phase C — Terraform state and infrastructure

First create the versioned encrypted S3 state bucket using an independent **local-state Terraform bootstrap** (protect that local bootstrap state file):

```bash
cd paintstudio-infra-live
bash scripts/setup-state.sh
# Review the generated backends/dev.hcl
terraform fmt -recursive       # format Terraform code before enabling CI fmt gate
bash scripts/plan-dev.sh
less dev-plan.txt
terraform apply dev.tfplan          # only after review
terraform output
```

`scripts/setup-state.sh` creates `paintstudio-dev-tfstate-ACCOUNTID-ap-south-1` with public-access block, versioning, encryption and accidental-destroy protection. The live backend uses S3 `use_lockfile=true`; ensure your Terraform version supports it and Jenkins IAM can read/write the bucket and lock object.

If Checkov reports findings, inspect each finding; don't blindly bypass the policy. This starter prioritizes teaching the workflow and is **not certified to pass every security policy** or regulatory requirement.

**Outputs:** `eks_cluster_name`, `ecr_url`, `rds_endpoint`, `rds_master_secret_arn`, `external_secrets_role_arn`, `fluentbit_role_arn`, `opensearch_endpoint`. None output DB passwords.

## Phase D — connect EKS, install Argo CD and External Secrets

```bash
aws eks update-kubeconfig --name paintstudio-dev --region ap-south-1
kubectl get nodes -o wide

# From bundle root
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace --wait

bash paintstudio-gitops/scripts/install-eso-dev.sh
bash paintstudio-gitops/scripts/bootstrap-dev-secrets.sh
kubectl -n paintstudio-dev get secretstore,externalsecret,secret,configmap
```

**What does ESO do?** Terraform creates a restricted IAM role trusted only by the `external-secrets/external-secrets` Kubernetes service account (IRSA). ESO reads the AWS-managed RDS master username/password from Secrets Manager into a Kubernetes Secret called `paintstudio-db`; the API uses those two values without storing plaintext in Git. Because the bootstrap commands create the SecretStore and ExternalSecret outside Argo CD, preserve them during teardown (Kubernetes deletion) and later move that declarative configuration under GitOps if required.

**TLS on SQL Server:** AWS RDS SQL Server uses TLS; .NET's SqlConnectionStringBuilder enables encryption and validates the server cert. Your container must trust the relevant RDS CA chain. Investigate trust errors rather than disabling validation outside local Compose.

## Phase E — build and publish FIRST image

Option A is Jenkins (Phase F) and automatic GitOps tag changes; if Jenkins is not ready, bootstrap manually from an AWS-authenticated Docker host:

```bash
cd paintstudio-app
REGION=ap-south-1
REPO=$(terraform -chdir=../paintstudio-infra-live output -raw ecr_url)
TAG=$(git rev-parse --short=12 HEAD)
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO%%/*}"
docker build -t "$REPO:$TAG" .
docker push "$REPO:$TAG"
python3 scripts/update_kustomize_tag.py ../paintstudio-gitops/overlays/dev/kustomization.yaml "$TAG"
# Commit and push updated GitOps overlay to its own repository.
```

Ensure `REPLACE_ACCOUNT_ID` in Dev overlay was substituted and changes were committed to GitOps repo. The deployment and migration job use the **same image reference** via Kustomize. Next bootstrap the Argo CD Application:

```bash
kubectl apply -n argocd -f ../paintstudio-gitops/applications/dev.yaml
kubectl -n argocd get applications
kubectl -n paintstudio-dev get pods,jobs,svc
kubectl -n paintstudio-dev logs job/paintstudio-migrate  # Job might have been deleted after success
kubectl -n paintstudio-dev port-forward svc/paintstudio 8080:80
```

Open **http://localhost:8080** and test saves/gallery. The Argo PreSync migration executes first; if it fails Argo CD will block the deployment, correctly avoiding starting the app against an incompatible schema.

## Phase F — Jenkins + SonarQube + Nexus + Vault + security gates

Jenkins/these tools are separate services; the included pipelines **do not provision a Jenkins server** automatically. For a local learning lab, `ci-tools/docker-compose.yml` provides SonarQube, Nexus, Vault, and Jenkins controller; its Vault uses **dev-only insecure mode** and must never be exposed publicly or treated as a real secret-management production instance. Prefer a private EC2 + Jenkins agent for builds in AWS, reachable securely through SSM/VPN. Jenkins controller must not have unnecessarily broad AWS credentials.

**Application Jenkins agent** label `linux-dotnet10-docker` and installed CLI tools: Git, .NET SDK 10, `dotnet-sonarscanner`, Python3, Docker, AWS CLI v2, Trivy, Gitleaks, tar, curl. AWS auth via EC2 instance profile or assumed IAM role (ECR only + minimally scoped). **Terraform Jenkins agent** label `terraform-aws` and Git/Terraform/Checkov/TFLint/Gitleaks/AWS role with approved Dev permissions. Deploy agents as isolated, nonshared trusted machines.

**Jenkins plugins / configuration:** Pipeline, Git, Credentials Binding, SonarQube Scanner, HashiCorp Vault, SSH Agent, Workspace Cleanup. Set up SonarQube server as Jenkins installation `sonarqube`; configure SonarQube webhook `https://JENKINS_URL/sonarqube-webhook/` with trailing slash. Create Jenkins secret-text credential `sonar-token` and GitOps deploy-key credential `gitops-deploy-key`; configure Vault AppRole credential `vault-approle`. For a private repo, check how Git checkout credentials are provided to the multibranch job.

**Vault:** Jenkinsfile reads KV v2 path `kv/ci/nexus` keys `username` / `password` using the Vault Jenkins plugin. Configure a correctly restricted Vault policy and short-lived AppRole; replace the example TLS URL. **Nexus:** create hosted RAW repository `paintstudio-raw`, set actual authenticated URL in `NEXUS_RAW_REPO`; built .NET `.tar.gz` artifact uploads there. **ECR:** immutable SHA-tagged OCI image and tag update; app pipeline must run with `main` and credentials to push only `paintstudio-gitops/overlays/dev` updates.

**Pipeline sequence:** checkout → Gitleaks → .NET restore/unit tests → Trivy filesystem scan → SonarQube/quality gate → Nexus artifact via Vault → Docker build + Trivy image scan → ECR push → GitOps SHA-tag update. Infra pipeline runs format/Gitleaks/Checkov/TFLint → init/validate → Dev plan → optional human approval → apply. Module pipeline validates each Terraform module independently. Enforce branch protection and use PR builds for untrusted changes; do not run untrusted PRs on privileged Docker agents.

## Phase G — Prometheus, Grafana and Slack

Create a Slack **incoming webhook** for `#paintstudio-dev-alerts`, then in the EKS monitoring namespace create a Kubernetes Secret **without saving the webhook URL in a shell history**:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
read -rs -p 'Slack webhook: ' SLACK_WEBHOOK; echo
kubectl -n monitoring create secret generic alertmanager-slack   --from-literal=webhook_url="$SLACK_WEBHOOK"
unset SLACK_WEBHOOK
bash paintstudio-gitops/scripts/install-monitoring-dev.sh
kubectl -n monitoring get servicemonitor,prometheusrule
kubectl -n monitoring get pods
```

Find the Grafana service with `kubectl -n monitoring get svc | grep grafana` and port-forward to it; find Prometheus and Alertmanager services similarly. Use Prometheus **Status → Targets** to inspect PaintStudio endpoint; when testing alerts, scale the Deployment down temporarily using GitOps (not manual `kubectl scale`, which Argo CD may promptly revert). Slack alert routing is configured in `monitoring-values.yaml`. The Grafana dashboard assumes the Prometheus datasource UID `prometheus`; verify the UID in Grafana Connections → Data sources, and change the JSON if your chart installed a different UID. Verify HTTP metric names in `/metrics` when adjusting queries.

## Phase H — OPTIONAL AWS OpenSearch application logs

RDS/EKS already incur meaningful costs: **do not enable OpenSearch before verifying Dev works**. When ready, update `paintstudio-infra-live/payloads/dev.json`:

```json
"opensearch": {
  "enabled": true,
  "data_nodes": 1,
  "volume_gb": 20,
  "admin_role_arn": "arn:aws:iam::YOUR_ACCOUNT:role/YOUR_EXISTING_OPENSEARCH_ADMIN_ROLE"
}
```

The admin ARN must identify an existing IAM **role** that can administer OpenSearch; do not substitute a temporary STS session ARN. Run `terraform plan`/`apply` again in the live repo. Terraform creates the ingest IAM role with service-account trust and grants domain HTTP permissions. **Critical:** OpenSearch fine-grained access control (FGAC) also needs an explicit backend-role mapping for the ingest IAM role to a suitably scoped index-writing role, performed by an OpenSearch administrator. An IAM allow policy does **not** by itself complete FGAC. Only then:

```bash
bash paintstudio-gitops/scripts/install-logging-dev.sh
kubectl -n logging get pods
kubectl -n logging logs ds/fluent-bit --tail=80
```

Fluent Bit tails `/var/log/containers/*paintstudio*.log`, signs AWS API requests with IRSA, and writes to `paintstudio-dev-*` indices. Use a VPC-connected OpenSearch Dashboards session to inspect logs. Deploy OpenSearch with a data retention plan before leaving it running; a single data node is **Dev-only**, not highly available.

## Quick diagnostics

```bash
kubectl -n argocd get applications
kubectl -n paintstudio-dev get deploy,po,svc,job,externalsecret,secretstore
kubectl -n paintstudio-dev describe externalsecret paintstudio-dev-rds
kubectl -n external-secrets logs deploy/external-secrets --tail=100
kubectl -n paintstudio-dev logs deploy/paintstudio --tail=100
kubectl -n monitoring get servicemonitors,prometheusrules
aws rds describe-db-instances --region ap-south-1 --query 'DBInstances[?contains(DBInstanceIdentifier, `paintstudio-dev`)].DBInstanceStatus'
```

## Cleanup (charges continue until this is complete)

**Delete Argo CD Application first and validate managed resources are gone** (remove app finalizers only if truly needed), then uninstall logging and monitoring Helm releases and ESO. If OpenSearch was enabled, disable it in payload and apply Terraform, or do a full `terraform destroy` after removing Kubernetes consumers. The root live state depends on the Git module tag, so don't delete module source or S3 state before destroy. Example:

```bash
kubectl -n argocd delete application paintstudio-dev --ignore-not-found
helm -n logging uninstall fluent-bit || true
helm -n monitoring uninstall monitoring || true
helm -n external-secrets uninstall external-secrets || true
helm -n argocd uninstall argocd || true
cd paintstudio-infra-live
terraform plan -destroy -var=payload_file=payloads/dev.json
terraform destroy -var=payload_file=payloads/dev.json
```

Destroying RDS with Dev `skip_final_snapshot=true` deletes its data. Make a snapshot first if useful. Confirm EKS nodes, NAT, RDS, EBS volumes, OpenSearch domain, load balancers, ECR images, and charged storage are deleted; clean up resources Terraform doesn't own. Keep S3 state bucket for audit until you verify destruction, then remove it deliberately (bootstrap state is protected). Empty ECR before destroy only after you have decided to delete its images.
