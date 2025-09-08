locals  {
  domain = data.aws_ssm_parameter.domain.value
  gh_user = "abikoP"
  # 機密情報もSSM Parameter Storeで管理（コスト削減）
  gh_token = data.aws_ssm_parameter.gh_token.value
  gh_webhook_secret = data.aws_ssm_parameter.gh_webhook_secret.value
  repo_allowlist = "github.com/platetech/terraform-iam-s3-project"
  
  # 共通タグ
  common_tags = {
    Project     = "atlantis"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}