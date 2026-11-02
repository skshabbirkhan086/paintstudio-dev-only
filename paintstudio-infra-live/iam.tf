data "aws_caller_identity" "current" {}

locals {
  oidc_host = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
}

data "aws_iam_policy_document" "eso_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}
resource "aws_iam_role" "external_secrets" {
  name               = "${local.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json
}
resource "aws_iam_role_policy" "read_rds_secret" {
  name = "read-rds-master-secret"
  role = aws_iam_role.external_secrets.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = module.sqlserver.master_user_secret_arn }]
  })
}

data "aws_iam_policy_document" "fluentbit_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:logging:fluent-bit"]
    }
  }
}
resource "aws_iam_role" "fluentbit" {
  name               = "${local.name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.fluentbit_trust.json
}
resource "aws_iam_role_policy" "fluentbit_es_write" {
  count = local.payload.opensearch.enabled ? 1 : 0
  name  = "write-paintstudio-opensearch"
  role  = aws_iam_role.fluentbit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["es:ESHttpPost", "es:ESHttpPut", "es:ESHttpGet", "es:ESHttpHead"]
      Resource = "arn:aws:es:${local.payload.region}:${data.aws_caller_identity.current.account_id}:domain/${local.name}/*"
    }]
  })
}
