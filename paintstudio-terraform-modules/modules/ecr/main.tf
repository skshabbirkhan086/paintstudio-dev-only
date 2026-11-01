terraform { required_version = ">= 1.10.0" }
variable "name" { type = string }
variable "kms_key_arn" { type = string }
resource "aws_ecr_repository" "repo" {
  name = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete = false
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key = var.kms_key_arn
  }
}
output "repository_url" { value = aws_ecr_repository.repo.repository_url }
