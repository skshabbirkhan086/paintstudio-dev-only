#!/usr/bin/env bash
# Run from anywhere after both Terraform and external-secrets Helm installation.
# Intentionally never prints database credentials.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/paintstudio-infra-live"
DB_HOST="$(terraform output -raw rds_endpoint)"
SECRET_ARN="$(terraform output -raw rds_master_secret_arn)"
ROLE_ARN="$(terraform output -raw external_secrets_role_arn)"
REGION="$(terraform output -raw region)"
[[ -n "$DB_HOST" && -n "$SECRET_ARN" && -n "$ROLE_ARN" ]]
kubectl create namespace paintstudio-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl -n paintstudio-dev create configmap paintstudio-config --from-literal=server="$DB_HOST" --dry-run=client -o yaml | kubectl apply -f -
# External Secrets Operator uses IAM role from its service-account annotation.
# Only the external-secrets controller assumes the IAM role; no AWS keys in Kubernetes.
cat <<EOF | kubectl -n paintstudio-dev apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: paintstudio-dev-aws
spec:
  provider:
    aws:
      service: SecretsManager
      region: $REGION
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: paintstudio-dev-rds
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: paintstudio-dev-aws
    kind: SecretStore
  target:
    name: paintstudio-db
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: $SECRET_ARN
        property: username
    - secretKey: password
      remoteRef:
        key: $SECRET_ARN
        property: password
EOF
kubectl -n paintstudio-dev wait --for=condition=Ready externalsecret/paintstudio-dev-rds --timeout=180s
kubectl -n paintstudio-dev get secret paintstudio-db -o jsonpath='{.metadata.name}{"\n"}'
echo 'Database secret synced without exposing password.'
