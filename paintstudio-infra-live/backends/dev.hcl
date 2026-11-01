# scripts/setup-state.sh generates this file after Terraform creates the state bucket.
# Do not run `terraform init` for the Dev root until this is configured.
bucket = "REPLACE_WITH_DEV_STATE_BUCKET"
key = "paintstudio/dev/terraform.tfstate"
region = "ap-south-1"
encrypt = true
use_lockfile = true
