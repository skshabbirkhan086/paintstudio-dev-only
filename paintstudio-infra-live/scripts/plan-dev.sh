#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform init -backend-config=backends/dev.hcl
terraform fmt -recursive
terraform fmt -check -recursive
terraform validate
terraform plan -var=payload_file=payloads/dev.json -out=dev.tfplan
terraform show -no-color dev.tfplan > dev-plan.txt
echo 'Review dev-plan.txt, then explicitly apply: terraform apply dev.tfplan'
