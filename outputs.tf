# VPCの出力
output "vpc_id" {
  description = "VPCのID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPCのCIDRブロック"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "プライベートサブネットのID"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "パブリックサブネットのID"
  value       = module.vpc.public_subnets
}

# Atlantisの出力
output "atlantis_url" {
  description = "AtlantisのURL"
  value       = module.atlantis.url
}

# output "atlantis_security_group_id" {
#   description = "AtlantisのセキュリティグループID"
#   value       = module.atlantis.ecs_security_group_id
# }

# Route53の出力
output "route53_zone_id" {
  description = "Route53ゾーンID"
  value       = data.aws_route53_zone.main.zone_id
}

output "domain_name" {
  description = "ドメイン名"
  value       = local.domain
  sensitive   = true
}
