terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.23"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
  # AWS_PROFILE環境変数から自動的に取得されます
  # export AWS_PROFILE=your-profile-name

  default_tags {
    tags = local.common_tags
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  tags = local.common_tags
}

module "atlantis" {
  source  = "terraform-aws-modules/atlantis/aws"
  version = "~> 4.0"

  name = "atlantis"

  # ECS Container Definition
  atlantis = {
    environment = [
      {
        name  = "ATLANTIS_GH_USER"
        value = local.gh_user
      },
      {
        name  = "ATLANTIS_REPO_ALLOWLIST"
        value = local.repo_allowlist
      },
      {
        name  = "ATLANTIS_GH_TOKEN"
        value = local.gh_token
      },
      {
        name  = "ATLANTIS_GH_WEBHOOK_SECRET"
        value = local.gh_webhook_secret
      },
    ]
    # Parameter Storeを使用するため、secretsブロックは不要
  }

  # ECS Service
  service = {
    # 最小権限の原則に従ったIAMロール
    tasks_iam_role_arn = aws_iam_role.atlantis_task_role.arn
  }
  service_subnets = module.vpc.public_subnets
  vpc_id          = module.vpc.vpc_id
  # ALB
  alb_subnets             = module.vpc.public_subnets
  certificate_domain_name = local.domain
  route53_zone_id         = data.aws_route53_zone.main.zone_id

  tags = local.common_tags
}