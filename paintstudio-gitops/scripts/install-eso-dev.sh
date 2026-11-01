#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROLE_ARN="$(terraform -chdir="$ROOT/paintstudio-infra-live" output -raw external_secrets_role_arn)"
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets   --namespace external-secrets --create-namespace   --set serviceAccount.create=true   --set serviceAccount.name=external-secrets   --set-string "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ROLE_ARN"   --wait
kubectl -n external-secrets rollout status deploy/external-secrets --timeout=180s
