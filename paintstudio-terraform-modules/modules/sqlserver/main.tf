terraform { required_version = ">= 1.10.0" }
variable "name" { type = string }
variable "vpc_id" { type = string }
variable "eks_node_security_group_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "db_class" { type = string }
variable "db_engine" { type = string }
variable "allocated_storage" { type = number }
variable "multi_az" { type = bool }
variable "kms_key_arn" { type = string }

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "SQL Server accessible only to Dev EKS worker nodes"
  vpc_id = var.vpc_id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.name}-sqlserver-sg" }
}
resource "aws_db_subnet_group" "private" {
  name = "${var.name}-db-subnets"
  subnet_ids = var.private_subnets
}
resource "aws_db_instance" "db" {
  identifier = "${var.name}-sqlserver"
  engine = var.db_engine
  instance_class = var.db_class
  allocated_storage = var.allocated_storage
  storage_type = "gp3"
  username = "paintadmin"
  manage_master_user_password = true
  license_model = "license-included"
  multi_az = var.multi_az
  storage_encrypted = true
  kms_key_id = var.kms_key_arn
  db_subnet_group_name = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible = false
  backup_retention_period = 7
  skip_final_snapshot = true # Dev only. Before destroy, take a manual snapshot if important.
  deletion_protection = false
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot = true
  tags = { Name = "${var.name}-sqlserver" }
}
output "endpoint" { value = aws_db_instance.db.address }
output "master_user_secret_arn" { value = try(aws_db_instance.db.master_user_secret[0].secret_arn, null) }
output "security_group_id" { value = aws_security_group.db.id }

resource "aws_vpc_security_group_ingress_rule" "eks_to_sql" {
  security_group_id = aws_security_group.db.id
  referenced_security_group_id = var.eks_node_security_group_id
  from_port = 1433
  to_port = 1433
  ip_protocol = "tcp"
  description = "Dev EKS workers to SQL Server"
}
