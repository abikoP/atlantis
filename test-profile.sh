#!/bin/bash

# AWS_PROFILE環境変数のテストスクリプト

echo "=== AWS_PROFILE 環境変数テスト ==="
echo ""

# 現在の環境変数を表示
echo "現在のAWS_PROFILE: ${AWS_PROFILE:-未設定}"

# スクリプト内での設定をテスト
readonly TEST_AWS_PROFILE="${AWS_PROFILE:-default}"
echo "スクリプト内での設定値: ${TEST_AWS_PROFILE}"

echo ""
echo "=== 使用例 ==="
echo "1. デフォルト（default）を使用:"
echo "   ./deploy.sh"
echo ""
echo "2. カスタムプロファイルを使用:"
echo "   export AWS_PROFILE=your-profile"
echo "   ./deploy.sh"
echo ""
echo "3. Fish Shellの場合:"
echo "   set -x AWS_PROFILE your-profile"
echo "   ./deploy.fish"
