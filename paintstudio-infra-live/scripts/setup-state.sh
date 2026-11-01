#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform -chdir=bootstrap-state init
terraform -chdir=bootstrap-state apply
BUCKET="$(terraform -chdir=bootstrap-state output -raw bucket_name)"
cat > backends/dev.hcl <<EOF
bucket = "$BUCKET"
key = "paintstudio/dev/terraform.tfstate"
region = "ap-south-1"
encrypt = true
use_lockfile = true
EOF
printf 'Dev remote state S3 bucket: %s\n' "$BUCKET"
echo 'Keep bootstrap-state/terraform.tfstate safe; the S3 bucket is protected from accidental destroy.'
