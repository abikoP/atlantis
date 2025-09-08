# SSM Parameter Storeからドメイン値を取得
data "aws_ssm_parameter" "domain" {
  name = "atlantis-domain"
}

# SSM Parameter Storeから値を取得
data "aws_ssm_parameter" "gh_token" {
  name            = "git_token"
  with_decryption = true  # SecureStringの場合は復号化
}

data "aws_ssm_parameter" "gh_webhook_secret" {
  name            = "gh_webhook_atlantis_secret"
  with_decryption = true  # SecureStringの場合は復号化
}

# Route53ゾーンを動的に取得
data "aws_route53_zone" "main" {
  name = data.aws_ssm_parameter.domain.value
}

# 現在のAWSアカウントIDを取得
data "aws_caller_identity" "current" {}

# 現在のAWSリージョンを取得
data "aws_region" "current" {}
