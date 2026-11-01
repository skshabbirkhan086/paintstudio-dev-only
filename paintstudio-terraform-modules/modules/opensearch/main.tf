terraform { required_version = ">= 1.10.0" }
variable "name" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "private_subnets" { type = list(string) }
variable "kms_key_arn" { type = string }
variable "admin_role_arn" { type = string }
variable "ingest_role_arn" { type = string }
variable "data_nodes" { type = number }
variable "volume_size" { type = number }

data "aws_caller_identity" "current" {}
resource "aws_security_group" "opensearch" {
  name_prefix = "${var.name}-os-"
  description = "Private HTTPS OpenSearch access within VPC"
  vpc_id = var.vpc_id
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_opensearch_domain" "domain" {
  domain_name = var.name
  engine_version = "OpenSearch_2.19" # Verify region support before enabling.
  cluster_config {
    instance_type = "r6g.large.search"
    instance_count = var.data_nodes
    zone_awareness_enabled = var.data_nodes > 1
    dynamic "zone_awareness_config" {
      for_each = var.data_nodes > 1 ? [1] : []
      content { availability_zone_count = var.data_nodes == 3 ? 3 : 2 }
    }
    dedicated_master_enabled = var.data_nodes == 3
    dedicated_master_type = var.data_nodes == 3 ? "r6g.large.search" : null
    dedicated_master_count = var.data_nodes == 3 ? 3 : null
  }
  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size
    volume_type = "gp3"
  }
  vpc_options {
    subnet_ids = slice(var.private_subnets, 0, var.data_nodes)
    security_group_ids = [aws_security_group.opensearch.id]
  }
  encrypt_at_rest {
    enabled = true
    kms_key_id = var.kms_key_arn
  }
  node_to_node_encryption { enabled = true }
  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-2-PFS-2023-10"
  }
  advanced_security_options {
    enabled = true
    internal_user_database_enabled = false
    master_user_options { master_user_arn = var.admin_role_arn }
  }
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { AWS = [var.admin_role_arn, var.ingest_role_arn] }
      Action = ["es:ESHttpGet", "es:ESHttpPost", "es:ESHttpPut", "es:ESHttpDelete", "es:ESHttpHead"]
      Resource = "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.name}/*"
    }]
  })
  tags = { Application = "PaintStudio" }
}
output "endpoint" { value = aws_opensearch_domain.domain.endpoint }
