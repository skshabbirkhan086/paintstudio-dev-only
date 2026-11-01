#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/paintstudio-infra-live"
OS_ENDPOINT="$(terraform output -raw opensearch_endpoint)"
[[ -n "$OS_ENDPOINT" ]] || { echo 'Enable opensearch.enabled in payloads/dev.json, Terraform apply first.' >&2; exit 1; }
ROLE_ARN="$(terraform output -raw fluentbit_role_arn)"
VALUES="$(mktemp)"; trap 'rm -f "$VALUES"' EXIT
python3 - "$ROOT/paintstudio-gitops/observability/fluent-bit-values.yaml" "$VALUES" "$OS_ENDPOINT" "$ROLE_ARN" <<'PY2'
from pathlib import Path
import sys
src,dst,host,role=sys.argv[1:]
s=Path(src).read_text().replace('REPLACE_OPENSEARCH_HOST',host)
# Can run before or after configure-dev.py.
import re
s=re.sub(r'arn:aws:iam::(?:REPLACE_ACCOUNT_ID|[0-9]{12}):role/paintstudio-dev-fluent-bit',role,s)
Path(dst).write_text(s)
PY2
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm upgrade --install fluent-bit fluent/fluent-bit --namespace logging --create-namespace --values "$VALUES" --wait
echo 'Verify IAM OpenSearch FGAC role mapping and query paintstudio-dev-* indices in Dashboards.'
