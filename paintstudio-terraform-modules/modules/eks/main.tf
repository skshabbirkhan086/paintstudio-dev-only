terraform { required_version = ">= 1.10.0" }
variable "name" { type = string }
variable "kubernetes_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "instance_type" { type = string }
variable "desired_size" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "public_access_cidrs" { type = list(string) }

module "cluster" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"
  name = var.name
  kubernetes_version = var.kubernetes_version
  endpoint_private_access = true
  endpoint_public_access = length(var.public_access_cidrs) > 0
  endpoint_public_access_cidrs = var.public_access_cidrs
  enable_irsa = true
  enable_cluster_creator_admin_permissions = true # lab bootstrap; replace with named access entries for production
  vpc_id = var.vpc_id
  subnet_ids = var.private_subnets
  addons = {
    coredns = {}
    "eks-pod-identity-agent" = { before_compute = true }
    kube-proxy = {}
    vpc-cni = { before_compute = true }
  }
  eks_managed_node_groups = {
    workers = {
      ami_type = "AL2023_x86_64_STANDARD"
      instance_types = [var.instance_type]
      desired_size = var.desired_size
      min_size = var.min_size
      max_size = var.max_size
    }
  }
  tags = { ManagedBy = "Terraform" }
}
output "cluster_name" { value = module.cluster.cluster_name }
output "cluster_endpoint" { value = module.cluster.cluster_endpoint }
output "oidc_provider_arn" { value = module.cluster.oidc_provider_arn }

output "cluster_oidc_issuer_url" { value = module.cluster.cluster_oidc_issuer_url }
output "node_security_group_id" { value = module.cluster.node_security_group_id }
