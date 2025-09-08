variable "environment" {
  description = "環境名 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "atlantis"
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "atlantis_repo_allowlist" {
  description = "Atlantisが管理するリポジトリの許可リスト"
  type        = list(string)
  default     = ["github.com/platetech/terraform-iam-s3-project"]
}

variable "enable_nat_gateway" {
  description = "NAT Gatewayを有効にするかどうか"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "VPN Gatewayを有効にするかどうか"
  type        = bool
  default     = false
}