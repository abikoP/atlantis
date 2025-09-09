#!/usr/bin/env fish

# =============================================================================
# Atlantis Terraform Deployment Script (Fish Shell)
# =============================================================================

set -g SCRIPT_NAME "Atlantis デプロイスクリプト"
set -g AWS_PROFILE (test -n "$AWS_PROFILE"; and echo $AWS_PROFILE; or echo "default")
set -g PROJECT_DIR (pwd)

# カラー設定
set -g GREEN '\033[0;32m'
set -g RED '\033[0;31m'
set -g YELLOW '\033[1;33m'
set -g BLUE '\033[0;34m'
set -g NC '\033[0m' # No Color

# ログ関数
function log_info
    echo -e "$BLUE[INFO]$NC $argv"
end

function log_success
    echo -e "$GREEN[SUCCESS]$NC $argv"
end

function log_warning
    echo -e "$YELLOW[WARNING]$NC $argv"
end

function log_error
    echo -e "$RED[ERROR]$NC $argv"
end

function show_banner
    echo "================================================================="
    echo "🚀 $SCRIPT_NAME"
    echo "================================================================="
    echo "プロファイル: $AWS_PROFILE"
    echo "プロジェクトディレクトリ: $PROJECT_DIR"
    echo "================================================================="
    echo ""
end

# 前提条件チェック
function check_prerequisites
    log_info "前提条件をチェックしています..."
    
    # AWS CLI チェック
    if not command -v aws >/dev/null 2>&1
        log_error "AWS CLI がインストールされていません"
        return 1
    end
    log_success "AWS CLI: 利用可能"
    
    # Terraform チェック
    if not command -v terraform >/dev/null 2>&1
        log_error "Terraform がインストールされていません"
        return 1
    end
    log_success "Terraform: 利用可能"
    
    # Terraformバージョン表示
    log_info "Terraformバージョン: "(terraform version -json | jq -r '.terraform_version')
    
    return 0
end

# AWS設定
function setup_aws_profile
    log_info "AWS プロファイルを設定しています..."
    set -gx AWS_PROFILE $AWS_PROFILE
    
    # AWS認証確認
    if not aws sts get-caller-identity >/dev/null 2>&1
        log_error "AWS認証に失敗しました。aws sso login --profile=$AWS_PROFILE を実行してください"
        return 1
    end
    
    set account_info (aws sts get-caller-identity)
    set account_id (echo $account_info | jq -r '.Account')
    set user_arn (echo $account_info | jq -r '.Arn')
    
    log_success "AWS認証成功"
    log_info "アカウントID: $account_id"
    log_info "ユーザーARN: $user_arn"
    
    return 0
end

# SSM Parameter Store確認
function check_ssm_parameters
    log_info "SSM Parameter Store の値を確認しています..."
    
    set required_params "atlantis-domain" "git_token" "gh_webhook_atlantis_secret"
    set missing_params
    
    for param in $required_params
        if aws ssm get-parameter --name $param --query "Parameter.Value" --output text >/dev/null 2>&1
            log_success "✅ $param: 存在"
        else
            log_error "❌ $param: 存在しません"
            set missing_params $missing_params $param
        end
    end
    
    if test (count $missing_params) -gt 0
        log_error "以下のパラメータが不足しています: $missing_params"
        log_info "パラメータ設定方法:"
        echo "aws ssm put-parameter --name 'atlantis-domain' --value 'your-domain.com' --type 'String'"
        echo "aws ssm put-parameter --name 'git_token' --value 'your-token' --type 'SecureString'"
        echo "aws ssm put-parameter --name 'gh_webhook_atlantis_secret' --value 'your-secret' --type 'SecureString'"
        return 1
    end
    
    return 0
end

# Route53確認
function check_route53_zone
    log_info "Route53ホストゾーンを確認しています..."
    
    set domain (aws ssm get-parameter --name "atlantis-domain" --query "Parameter.Value" --output text)
    set zone_info (aws route53 list-hosted-zones --query "HostedZones[?Name=='$domain.'].{Name:Name,Id:Id}" --output json)
    
    if test (echo $zone_info | jq length) -gt 0
        set zone_id (echo $zone_info | jq -r '.[0].Id' | string replace '/hostedzone/' '')
        log_success "✅ Route53ゾーン存在: $domain (ID: $zone_id)"
    else
        log_error "❌ Route53ゾーンが見つかりません: $domain"
        return 1
    end
    
    return 0
end

# Terraformクリーンアップ
function cleanup_terraform
    log_info "Terraformの状態をクリーンアップしています..."
    
    if test -d .terraform
        rm -rf .terraform
        log_success "既存の .terraform ディレクトリを削除しました"
    end
    
    if test -f .terraform.lock.hcl
        rm -f .terraform.lock.hcl
        log_success "既存の .terraform.lock.hcl を削除しました"
    end
end

# Terraform初期化
function terraform_init
    log_info "Terraformを初期化しています..."
    
    if terraform init -upgrade
        log_success "Terraform初期化完了"
        return 0
    else
        log_error "Terraform初期化に失敗しました"
        return 1
    end
end

# Terraformプラン
function terraform_plan
    log_info "Terraformプランを実行しています..."
    
    if terraform plan -out=tfplan
        log_success "Terraformプラン完了"
        log_info "プランファイル: tfplan が作成されました"
        return 0
    else
        log_error "Terraformプランに失敗しました"
        return 1
    end
end

# Terraform適用
function terraform_apply
    log_warning "🚨 Terraformを適用します。AWSリソースが作成されます。"
    echo ""
    echo -n "続行しますか？ [y/N]: "
    read -l response
    
    if test "$response" = "y" -o "$response" = "Y"
        log_info "Terraformを適用しています..."
        
        if terraform apply tfplan
            log_success "🎉 デプロイ完了！"
            echo ""
            log_info "出力値を表示しています..."
            terraform output
            return 0
        else
            log_error "Terraform適用に失敗しました"
            return 1
        end
    else
        log_info "デプロイをキャンセルしました"
        return 1
    end
end

# メイン実行
function main
    show_banner
    
    # 各ステップを実行
    check_prerequisites; or return 1
    setup_aws_profile; or return 1
    check_ssm_parameters; or return 1
    check_route53_zone; or return 1
    cleanup_terraform
    terraform_init; or return 1
    terraform_plan; or return 1
    terraform_apply; or return 1
    
    log_success "🎯 全ての処理が完了しました！"
    echo ""
    echo "Next Steps:"
    echo "1. https://your-domain.com でAtlantisにアクセス"
    echo "2. GitHubリポジトリでWebhook設定"
    echo "3. Pull Requestでテスト実行"
end

# スクリプト実行
main $argv
