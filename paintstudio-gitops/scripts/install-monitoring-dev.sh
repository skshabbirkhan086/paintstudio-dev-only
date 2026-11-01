#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! kubectl -n monitoring get secret alertmanager-slack >/dev/null 2>&1; then
  echo 'Create Slack secret FIRST (read README); aborting.' >&2; exit 1
fi
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack   --namespace monitoring --create-namespace --values observability/monitoring-values.yaml --wait
kubectl apply -f observability/servicemonitor.yaml
kubectl apply -f observability/prometheusrule.yaml
kubectl -n monitoring create configmap paintstudio-dev-dashboard   --from-file=paintstudio-dev.json=observability/grafana-dashboard.json   --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
echo 'Prometheus and alerts deployed. Verify Grafana/targets/alertmanager in port-forward URLs.'
