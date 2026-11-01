terraform {
  required_version = ">= 1.10.0"
}
variable "name" { type = string }
variable "cidr" { type = string }
variable "azs" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "single_nat_gateway" { type = bool }
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"
  name = var.name
  cidr = var.cidr
  azs  = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support = true
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  tags = { ManagedBy = "Terraform" }
}
output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnets" { value = module.vpc.private_subnets }
output "public_subnets" { value = module.vpc.public_subnets }
