# PaintStudio GitOps — DEV ONLY

- `applications/dev.yaml`: Argo CD Application watching `main` branch and `overlays/dev`.
- `base/`: nonprivileged ASP.NET Core Deployment, ClusterIP Service, PreSync SQL migration Job.
- `overlays/dev/`: Kustomize namespace/image/replica settings. The sole `newTag` is updated by Jenkins on successful `main` builds. Do not keep `bootstrap` as a real deploy tag.
- `scripts/install-eso-dev.sh`: installs External Secrets Operator using the IAM role output of Dev Terraform.
- `scripts/bootstrap-dev-secrets.sh`: creates namespace, DB host ConfigMap, SecretStore, ExternalSecret — **never fetches or prints master password**.
- `observability/`: kube-prometheus-stack values, PaintStudio ServiceMonitor, PrometheusRule, Grafana dashboard JSON; Slack Alertmanager configuration, and optional Fluent Bit Helm values for OpenSearch.
- `scripts/install-monitoring-dev.sh`: installs monitoring after the user creates a Slack webhook Secret.
- `scripts/install-logging-dev.sh`: installs Fluent Bit after optional OpenSearch is enabled and fine-grained role mapping is configured.

**Order:** Terraform → EKS auth → Helm Argo CD + ESO → bootstrap RDS Secret → ECR image upload → commit GitOps image tag → `kubectl apply -n argocd -f applications/dev.yaml` → app health check → monitoring → optional logging.

All apps remain accessible through **kubectl port-forward** only. Do not add public ingress without authentication/authorization design. Further details: bundle root `DEV_RUNBOOK.md`.
