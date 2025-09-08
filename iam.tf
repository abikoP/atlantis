# Atlantis最小権限IAMポリシー
data "aws_iam_policy_document" "atlantis_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "atlantis_policy" {
  # Terraform state管理
  statement {
    sid = "TerraformStateManagement"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::terraform-state-*",
      "arn:aws:s3:::terraform-state-*/*"
    ]
  }

  # DynamoDB for state locking
  statement {
    sid = "TerraformStateLocking"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    ]
  }

  # SSM Parameter Store読み取り権限
  statement {
    sid = "SSMParameterStoreRead"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/git_token",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/gh_webhook_atlantis_secret",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/atlantis-domain"
    ]
  }

  # KMS復号化権限（SecureStringの場合）
  statement {
    sid = "KMSDecryption"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${data.aws_region.current.name}.amazonaws.com"]
    }
  }

  # 必要最小限のEC2権限
  statement {
    sid = "EC2ManagementMinimal"
    actions = [
      "ec2:Describe*",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]
  }

  # IAM読み取り権限（必要に応じて）
  statement {
    sid = "IAMReadOnly"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "atlantis_task_role" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.atlantis_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "atlantis_policy" {
  name   = "${var.project_name}-policy"
  role   = aws_iam_role.atlantis_task_role.id
  policy = data.aws_iam_policy_document.atlantis_policy.json
}
