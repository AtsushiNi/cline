#!/bin/bash

# Cline ローカルパッケージングスクリプト
# シンプルにローカル環境で .vsix ファイルを生成します

set -e

echo "=== Cline ローカルパッケージング ==="
echo ""

# 必要なツールの確認
echo "1. 必要なツールを確認しています..."
if ! command -v node &> /dev/null; then
    echo "エラー: Node.js がインストールされていません"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "エラー: npm がインストールされていません"
    exit 1
fi

echo "✓ Node.js と npm は利用可能です"

# 依存関係の確認
echo ""
echo "2. 依存関係を確認しています..."
if [ ! -d "node_modules" ] || [ ! -d "webview-ui/node_modules" ]; then
    echo "警告: 依存関係がインストールされていないようです"
    echo "      npm install を実行することをお勧めします"
    read -p "続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "終了します"
        exit 0
    fi
else
    echo "✓ 依存関係はインストール済みです"
fi

# Protobuf のコンパイル
echo ""
echo "3. Protobuf をコンパイルしています..."
npm run protos
if [ $? -eq 0 ]; then
    echo "✓ Protobuf コンパイル完了"
else
    echo "✗ Protobuf コンパイルに失敗しました"
    exit 1
fi

# タイプチェック
echo ""
echo "4. タイプチェックを実行しています..."
npm run check-types
if [ $? -eq 0 ]; then
    echo "✓ タイプチェック完了"
else
    echo "✗ タイプチェックに失敗しました"
    exit 1
fi

# webview-ui のビルド
echo ""
echo "6. webview-ui をビルドしています..."
npm run build:webview
if [ $? -eq 0 ]; then
    echo "✓ webview-ui ビルド完了"
else
    echo "✗ webview-ui ビルドに失敗しました"
    exit 1
fi

# 拡張機能のビルド
echo ""
echo "7. 拡張機能をビルドしています..."
npm run package
if [ $? -eq 0 ]; then
    echo "✓ 拡張機能ビルド完了"
else
    echo "✗ 拡張機能ビルドに失敗しました"
    exit 1
fi

# .vsix ファイルの生成
echo ""
echo "8. .vsix ファイルを生成しています..."

# vsce が利用可能か確認
if ! npx vsce --version &> /dev/null; then
    echo "エラー: vsce が利用できません"
    echo "      npm install -g @vscode/vsce を実行してください"
    exit 1
fi

# パッケージ情報からバージョンを取得
VERSION=$(node -p "require('./package.json').version")
VSIX_NAME="cline-local-${VERSION}.vsix"

npx vsce package --allow-package-secrets sendgrid --out "$VSIX_NAME"
if [ $? -eq 0 ]; then
    echo "✓ .vsix ファイル生成完了: $VSIX_NAME"
    
    # ファイル情報の表示
    echo ""
    echo "=== 生成されたファイル ==="
    ls -lh "$VSIX_NAME"
    
    # インストール方法の表示
    echo ""
    echo "=== インストール方法 ==="
    echo "次のコマンドで VS Code にインストールできます:"
    echo "  code --install-extension $VSIX_NAME"
else
    echo "✗ .vsix ファイル生成に失敗しました"
    exit 1
fi

echo ""
echo "=== パッケージング完了 ==="
echo "生成されたファイル: $VSIX_NAME"
echo "サイズ: $(ls -lh "$VSIX_NAME" | awk '{print $5}')"
echo ""
echo "VS Code にインストール: code --install-extension $VSIX_NAME"
