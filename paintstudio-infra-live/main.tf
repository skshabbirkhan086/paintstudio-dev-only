locals {
  payload = jsondecode(file("${path.module}/${var.payload_file}"))
  name = "paintstudio-dev"
}
provider "aws" {
  region = local.payload.region
  default_tags {
    tags = {
      Application = "PaintStudio"
      Environment = local.payload.environment
      ManagedBy = "Terraform"
    }
  }
}
data "aws_availability_zones" "available" { state = "available" }

# Set skshabbirkhan086 with scripts/configure-dev.py, then push the tag v0.1.0 to module Git repo.
module "network" {
  source = "git::https://github.com/skshabbirkhan086/paintstudio-dev-only.git//paintstudio-terraform-modules/modules/network?ref=v0.1.0"
  name = local.name
  cidr = local.payload.network.vpc_cidr
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = local.payload.network.private_subnets
  public_subnets = local.payload.network.public_subnets
  single_nat_gateway = local.payload.network.single_nat_gateway
}
module "eks" {
  source = "git::https://github.com/skshabbirkhan086/paintstudio-dev-only.git//paintstudio-terraform-modules/modules/eks?ref=v0.1.0"
  name = local.name
  kubernetes_version = local.payload.eks.version
  vpc_id = module.network.vpc_id
  private_subnets = module.network.private_subnets
  instance_type = local.payload.eks.instance_type
  desired_size = local.payload.eks.desired_size
  min_size = local.payload.eks.min_size
  max_size = local.payload.eks.max_size
  public_access_cidrs = local.payload.eks.public_access_cidrs
}
resource "aws_kms_key" "data" {
  description = "${local.name} data encryption"
  enable_key_rotation = true
  deletion_window_in_days = 30
}
resource "aws_kms_alias" "data" {
  name = "alias/${local.name}-data"
  target_key_id = aws_kms_key.data.key_id
}
module "ecr" {
  source = "git::https://github.com/skshabbirkhan086/paintstudio-dev-only.git//paintstudio-terraform-modules/modules/ecr?ref=v0.1.0"
  name = local.name
  kms_key_arn = aws_kms_key.data.arn
}
module "sqlserver" {
  source = "git::https://github.com/skshabbirkhan086/paintstudio-dev-only.git//paintstudio-terraform-modules/modules/sqlserver?ref=v0.1.0"
  name = local.name
  vpc_id = module.network.vpc_id
  eks_node_security_group_id = module.eks.node_security_group_id
  private_subnets = module.network.private_subnets
  db_engine = local.payload.sqlserver.engine
  db_class = local.payload.sqlserver.instance_class
  allocated_storage = local.payload.sqlserver.storage_gb
  multi_az = local.payload.sqlserver.multi_az
  kms_key_arn = aws_kms_key.data.arn
}

# Enable OpenSearch only in Dev logging phase; high ongoing hourly cost.
module "opensearch" {
  count = local.payload.opensearch.enabled ? 1 : 0
  source = "git::https://github.com/skshabbirkhan086/paintstudio-dev-only.git//paintstudio-terraform-modules/modules/opensearch?ref=v0.1.0"
  name = local.name
  region = local.payload.region
  vpc_id = module.network.vpc_id
  vpc_cidr = local.payload.network.vpc_cidr
  private_subnets = module.network.private_subnets
  kms_key_arn = aws_kms_key.data.arn
  admin_role_arn = local.payload.opensearch.admin_role_arn
  ingest_role_arn = aws_iam_role.fluentbit.arn
  data_nodes = local.payload.opensearch.data_nodes
  volume_size = local.payload.opensearch.volume_gb
}
