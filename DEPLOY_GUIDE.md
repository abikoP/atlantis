# デプロイスクリプト使用ガイド

## 概要
このディレクトリには、Atlantis Terraformプロジェクトを自動デプロイするためのスクリプトが含まれています。

## ファイル説明

### 🐟 Fish Shell版
- **ファイル**: `deploy.fish`
- **対象**: Fish Shell ユーザー
- **特徴**: Fish Shell の構文を使用、よりモダンなシェル機能

### 🐚 Bash版
- **ファイル**: `deploy.sh`
- **対象**: Bash ユーザー（より汎用的）
- **特徴**: POSIX互換、ほとんどのLinux/macOSで動作

## 使用方法

### 1. 基本的なデプロイ実行

#### Fish Shell版
```bash
# デフォルトプロファイル（default）でデプロイ
./deploy.fish

# カスタムプロファイルでデプロイ
set -x AWS_PROFILE your-profile-name
./deploy.fish
```

#### Bash版
```bash
# デフォルトプロファイル（default）でデプロイ
./deploy.sh
# または
./deploy.sh deploy

# カスタムプロファイルでデプロイ
export AWS_PROFILE=your-profile-name
./deploy.sh deploy
```

### 2. プランのみ実行（Bash版のみ）
```bash
./deploy.sh plan
```

### 3. リソース削除（Bash版のみ）
```bash
./deploy.sh destroy
```

### 4. ヘルプ表示（Bash版のみ）
```bash
./deploy.sh help
```

## 前提条件

### 必要なツール
- ✅ AWS CLI v2
- ✅ Terraform >= 1.0
- ✅ jq（JSON処理）
- ✅ Fish Shell または Bash

### AWSの設定
1. **プロファイル**: デフォルト`default`、環境変数`AWS_PROFILE`で変更可能
2. **SSO認証**: 事前に`aws sso login --profile=${AWS_PROFILE}`を実行
3. **権限**: AdministratorAccess相当の権限

### 環境変数設定（オプション）
```bash
# 異なるプロファイルを使用する場合
export AWS_PROFILE=your-profile-name

# Fish Shell版の場合
set -x AWS_PROFILE your-profile-name
```

### SSM Parameter Store設定
以下のパラメータが設定済みである必要があります：

```bash
# ドメイン名
aws ssm put-parameter \
  --name "atlantis-domain" \
  --value "your-domain.com" \
  --type "String"

# GitHub Personal Access Token
aws ssm put-parameter \
  --name "git_token" \
  --value "ghp_your-token" \
  --type "SecureString"

# GitHub Webhook Secret
aws ssm put-parameter \
  --name "gh_webhook_atlantis_secret" \
  --value "your-webhook-secret" \
  --type "SecureString"
```

## スクリプトの動作フロー

1. **前提条件チェック** - 必要なツールの存在確認
2. **AWS認証確認** - プロファイルと認証状態の確認
3. **SSMパラメータ確認** - 必要なパラメータの存在確認
4. **Route53確認** - ドメインのホストゾーン確認
5. **Terraformクリーンアップ** - 既存状態のクリーンアップ
6. **Terraform初期化** - プロバイダーとモジュールの初期化
7. **Terraformプラン** - 実行計画の作成と確認
8. **Terraform適用** - ユーザー確認後にリソース作成

## デプロイ後の確認事項

### 作成されるリソース（49個）
- **VPC**: 1個のVPC、6個のサブネット
- **ECS**: クラスター、サービス、タスク定義
- **ALB**: ロードバランサー、リスナー、ターゲットグループ
- **Route53**: DNSレコード、SSL証明書
- **IAM**: 必要な権限とロール
- **セキュリティグループ**: 適切なネットワーク制御

### 次のステップ
1. **Atlantisアクセス**: `https://your-domain.com`
2. **GitHub Webhook設定**: リポジトリでWebhook設定
3. **テスト実行**: Pull Requestでテスト

## トラブルシューティング

### よくある問題

#### 1. AWS認証エラー
```bash
# デフォルトプロファイルの場合
aws sso login --profile=default

# カスタムプロファイルの場合
aws sso login --profile=${AWS_PROFILE}
```

#### 2. SSMパラメータ不足
```bash
# パラメータ一覧確認
aws ssm describe-parameters --query "Parameters[?starts_with(Name, 'atlantis') || starts_with(Name, 'git') || starts_with(Name, 'gh_webhook')].Name"
```

#### 3. Terraformプロバイダータイムアウト
```bash
# クリーンアップして再実行
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### 4. Route53ゾーン不足
```bash
# ホストゾーン作成
aws route53 create-hosted-zone --name your-domain.com --caller-reference $(date +%s)
```

## ログレベル
- 🔵 **[INFO]**: 一般的な情報
- 🟢 **[SUCCESS]**: 成功した操作
- 🟡 **[WARNING]**: 注意が必要な操作
- 🔴 **[ERROR]**: エラーが発生した操作

## セキュリティ考慮事項
- スクリプトは機密情報をログに出力しません
- SSMパラメータの値は暗号化されて保存
- IAMロールは最小権限の原則に従って設定
- NAT Gatewayは無効化でコスト最適化済み
