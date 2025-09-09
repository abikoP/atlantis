#!/bin/bash

# =============================================================================
# Atlantis Terraform Deployment Script (Bash)
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="Atlantis デプロイスクリプト"
readonly AWS_PROFILE="${AWS_PROFILE:-default}"
readonly PROJECT_DIR
PROJECT_DIR="$(pwd)"

# カラー設定
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

show_banner() {
    echo "================================================================="
    echo "🚀 ${SCRIPT_NAME}"
    echo "================================================================="
    echo "プロファイル: ${AWS_PROFILE}"
    echo "プロジェクトディレクトリ: ${PROJECT_DIR}"
    echo "================================================================="
    echo ""
}

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェックしています..."
    
    # AWS CLI チェック
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI がインストールされていません"
        return 1
    fi
    log_success "AWS CLI: 利用可能"
    
    # Terraform チェック
    if ! command -v terraform >/dev/null 2>&1; then
        log_error "Terraform がインストールされていません"
        return 1
    fi
    log_success "Terraform: 利用可能"
    
    # jq チェック
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq がインストールされていません"
        return 1
    fi
    log_success "jq: 利用可能"
    
    # Terraformバージョン表示
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraformバージョン: ${tf_version}"
    
    return 0
}

# AWS設定
setup_aws_profile() {
    log_info "AWS プロファイルを設定しています..."
    export AWS_PROFILE="${AWS_PROFILE}"
    
    # AWS認証確認
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS認証に失敗しました。aws sso login --profile=${AWS_PROFILE} を実行してください"
        return 1
    fi
    
    local account_info account_id user_arn
    account_info=$(aws sts get-caller-identity)
    account_id=$(echo "${account_info}" | jq -r '.Account')
    user_arn=$(echo "${account_info}" | jq -r '.Arn')
    
    log_success "AWS認証成功"
    log_info "アカウントID: ${account_id}"
    log_info "ユーザーARN: ${user_arn}"
    
    return 0
}

# SSM Parameter Store確認
check_ssm_parameters() {
    log_info "SSM Parameter Store の値を確認しています..."
    
    local required_params=("atlantis-domain" "git_token" "gh_webhook_atlantis_secret")
    local missing_params=()
    
    for param in "${required_params[@]}"; do
        if aws ssm get-parameter --name "${param}" --query "Parameter.Value" --output text >/dev/null 2>&1; then
            log_success "✅ ${param}: 存在"
        else
            log_error "❌ ${param}: 存在しません"
            missing_params+=("${param}")
        fi
    done
    
    if [ ${#missing_params[@]} -gt 0 ]; then
        log_error "以下のパラメータが不足しています: ${missing_params[*]}"
        log_info "パラメータ設定方法:"
        echo "aws ssm put-parameter --name 'atlantis-domain' --value 'your-domain.com' --type 'String'"
        echo "aws ssm put-parameter --name 'git_token' --value 'your-token' --type 'SecureString'"
        echo "aws ssm put-parameter --name 'gh_webhook_atlantis_secret' --value 'your-secret' --type 'SecureString'"
        return 1
    fi
    
    return 0
}

# Route53確認
check_route53_zone() {
    log_info "Route53ホストゾーンを確認しています..."
    
    local domain zone_info zone_count zone_id
    domain=$(aws ssm get-parameter --name "atlantis-domain" --query "Parameter.Value" --output text)
    zone_info=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${domain}.'].{Name:Name,Id:Id}" --output json)
    zone_count=$(echo "${zone_info}" | jq length)
    
    if [ "${zone_count}" -gt 0 ]; then
        zone_id=$(echo "${zone_info}" | jq -r '.[0].Id' | sed 's|/hostedzone/||')
        log_success "✅ Route53ゾーン存在: ${domain} (ID: ${zone_id})"
    else
        log_error "❌ Route53ゾーンが見つかりません: ${domain}"
        return 1
    fi
    
    return 0
}

# Terraformクリーンアップ
cleanup_terraform() {
    log_info "Terraformの状態をクリーンアップしています..."
    
    if [ -d .terraform ]; then
        rm -rf .terraform
        log_success "既存の .terraform ディレクトリを削除しました"
    fi
    
    if [ -f .terraform.lock.hcl ]; then
        rm -f .terraform.lock.hcl
        log_success "既存の .terraform.lock.hcl を削除しました"
    fi
}

# Terraform初期化
terraform_init() {
    log_info "Terraformを初期化しています..."
    
    if terraform init -upgrade; then
        log_success "Terraform初期化完了"
        return 0
    else
        log_error "Terraform初期化に失敗しました"
        return 1
    fi
}

# Terraformプラン
terraform_plan() {
    log_info "Terraformプランを実行しています..."
    
    if terraform plan -out=tfplan; then
        log_success "Terraformプラン完了"
        log_info "プランファイル: tfplan が作成されました"
        return 0
    else
        log_error "Terraformプランに失敗しました"
        return 1
    fi
}

# Terraform適用
terraform_apply() {
    log_warning "🚨 Terraformを適用します。AWSリソースが作成されます。"
    echo ""
    read -p "続行しますか？ [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Terraformを適用しています..."
        
        if terraform apply tfplan; then
            log_success "🎉 デプロイ完了！"
            echo ""
            log_info "出力値を表示しています..."
            terraform output
            return 0
        else
            log_error "Terraform適用に失敗しました"
            return 1
        fi
    else
        log_info "デプロイをキャンセルしました"
        return 1
    fi
}

# Terraform破棄（オプション）
terraform_destroy() {
    log_warning "🚨 全てのAWSリソースを削除します。この操作は元に戻せません。"
    echo ""
    read -p "本当に削除しますか？ [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Terraformリソースを削除しています..."
        
        if terraform destroy -auto-approve; then
            log_success "🗑️ 全てのリソースが削除されました"
            return 0
        else
            log_error "Terraform削除に失敗しました"
            return 1
        fi
    else
        log_info "削除をキャンセルしました"
        return 1
    fi
}

# ヘルプ表示
show_help() {
    echo "使用方法: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  deploy     デプロイを実行（デフォルト）"
    echo "  plan       プランのみ実行"
    echo "  destroy    全てのリソースを削除"
    echo "  help       このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0 deploy     # フルデプロイ実行"
    echo "  $0 plan       # プランのみ実行"
    echo "  $0 destroy    # リソース削除"
}

# メイン実行
main() {
    local action="${1:-deploy}"
    
    case "${action}" in
        "deploy")
            show_banner
            check_prerequisites || return 1
            setup_aws_profile || return 1
            check_ssm_parameters || return 1
            check_route53_zone || return 1
            cleanup_terraform
            terraform_init || return 1
            terraform_plan || return 1
            terraform_apply || return 1
            
            log_success "🎯 全ての処理が完了しました！"
            echo ""
            echo "Next Steps:"
            echo "1. https://your-domain.com でAtlantisにアクセス"
            echo "2. GitHubリポジトリでWebhook設定"
            echo "3. Pull Requestでテスト実行"
            ;;
        "plan")
            show_banner
            check_prerequisites || return 1
            setup_aws_profile || return 1
            cleanup_terraform
            terraform_init || return 1
            terraform_plan || return 1
            ;;
        "destroy")
            show_banner
            check_prerequisites || return 1
            setup_aws_profile || return 1
            terraform_destroy || return 1
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "不明なオプション: ${action}"
            show_help
            return 1
            ;;
    esac
}

# スクリプト実行
main "$@"
