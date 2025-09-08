# Atlantis Terraform プロジェクト

## 概要
このプロジェクトは、AWS上でAtlantisを構築するためのTerraformコードです。

## 前提条件

### AWS SSM Parameter Store設定
以下のパラメータを事前にAWS SSM Parameter Storeに設定してください：

```bash
# ドメイン名
aws ssm put-parameter \
  --name "atlantis-domain" \
  --value "your-domain.com" \
  --type "String"

# GitHub Personal Access Token（SecureStringで暗号化）
aws ssm put-parameter \
  --name "git_token" \
  --value "ghp_your-github-token" \
  --type "SecureString" \
  --description "GitHub Personal Access Token for Atlantis"

# GitHub Webhook Secret（SecureStringで暗号化）
aws ssm put-parameter \
  --name "gh_webhook_atlantis_secret" \
  --value "your-webhook-secret" \
  --type "SecureString" \
  --description "GitHub Webhook Secret for Atlantis"
```

### コスト最適化
- Secrets Manager ($0.40/月 per secret) から SSM Parameter Store ($0.05/月 per 10,000 requests) に変更
- SecureStringタイプで暗号化も可能
- 大幅なコスト削減を実現

## 使用方法

1. **環境変数ファイルの作成**
```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを環境に合わせて編集
```

2. **Terraformの初期化**
```bash
terraform init
```

3. **プランの確認**
```bash
terraform plan
```

4. **適用**
```bash
terraform apply
```

## ファイル構成

- `main.tf` - メインの設定
- `variables.tf` - 変数定義
- `locals.tf` - ローカル値
- `data.tf` - データソース
- `iam.tf` - IAM関連の設定
- `outputs.tf` - 出力値
- `.gitignore` - Git除外設定

## セキュリティ

- すべての機密情報はSSM Parameter Store（SecureString）で暗号化管理
- IAMロールは最小権限の原則に従って設定
- ハードコードされた値を排除
- Secrets Managerよりも大幅にコスト削減

## 改善点

1. ✅ セキュリティの向上（最小権限IAM、機密情報の適切な管理）
2. ✅ 設定の柔軟性向上（変数化、環境別設定）
3. ✅ コードの可読性向上（ファイル分割、コメント）
4. ✅ 保守性の向上（出力値、文書化）
