#!/bin/bash

# Cline Extension Docker Build Script
# このスクリプトはDockerを使用してCline拡張機能をビルドします

set -e

# デフォルト値の設定
IMAGE_NAME="cline-builder"
IMAGE_TAG="latest"
OUTPUT_DIR="./docker-output"
EXTRACT_VSIX=true
VSIX_NAME="cline-docker-build.vsix"

# ヘルプメッセージ
show_help() {
    cat << EOF
Cline Extension Docker Build Script

使用方法: $0 [オプション]

オプション:
  -h, --help          このヘルプメッセージを表示
  -t, --tag TAG        Dockerイメージのタグを指定（デフォルト: latest）
  -o, --output DIR     出力ディレクトリを指定（デフォルト: ./docker-output）
  -n, --name NAME      出力する.vsixファイルの名前を指定（デフォルト: cline-docker-build.vsix）
  --no-extract         .vsixファイルを抽出しない（Dockerコンテナ内に留める）
  --skip-build         Dockerビルドをスキップ（既存のイメージを使用）

例:
  $0                   デフォルト設定でビルド
  $0 -t v1.0.0         タグを指定してビルド
  $0 -o ./builds       出力ディレクトリを変更
EOF
}

# 引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -n|--name)
            VSIX_NAME="$2"
            shift 2
            ;;
        --no-extract)
            EXTRACT_VSIX=false
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo "エラー: 不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# 出力ディレクトリの作成
mkdir -p "$OUTPUT_DIR"

echo "=== Cline Docker Build ==="
echo "イメージ名: $IMAGE_NAME:$IMAGE_TAG"
echo "出力ディレクトリ: $OUTPUT_DIR"
echo "VSIXファイル名: $VSIX_NAME"
echo "=========================="
echo ""

# Dockerイメージのビルド（スキップしない場合）
if [[ "$SKIP_BUILD" != "true" ]]; then
    echo "1. Dockerイメージをビルドしています..."
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
    
    if [ $? -eq 0 ]; then
        echo "✓ Dockerイメージのビルドが完了しました: $IMAGE_NAME:$IMAGE_TAG"
    else
        echo "✗ Dockerイメージのビルドに失敗しました"
        exit 1
    fi
else
    echo "1. Dockerビルドをスキップします（既存のイメージを使用）"
fi

# .vsixファイルの抽出
if [[ "$EXTRACT_VSIX" == "true" ]]; then
    echo ""
    echo "2. .vsixファイルを抽出しています..."
    
    # 一時コンテナの作成と実行
    CONTAINER_ID=$(docker create "$IMAGE_NAME:$IMAGE_TAG")
    
    # .vsixファイルをコンテナからコピー
    docker cp "$CONTAINER_ID:/app/cline-build.vsix" "$OUTPUT_DIR/$VSIX_NAME"
    
    # 一時コンテナの削除
    docker rm "$CONTAINER_ID" > /dev/null
    
    if [ -f "$OUTPUT_DIR/$VSIX_NAME" ]; then
        echo "✓ .vsixファイルの抽出が完了しました: $OUTPUT_DIR/$VSIX_NAME"
        
        # ファイル情報の表示
        echo ""
        echo "生成されたファイル情報:"
        echo "----------------------"
        ls -lh "$OUTPUT_DIR/$VSIX_NAME"
        
        # パッケージ情報の表示
        echo ""
        echo "拡張機能情報:"
        echo "-------------"
        docker run --rm "$IMAGE_NAME:$IMAGE_TAG"
    else
        echo "✗ .vsixファイルの抽出に失敗しました"
        exit 1
    fi
else
    echo ""
    echo "2. .vsixファイルの抽出をスキップします"
    echo "   コンテナを実行して情報を表示: docker run --rm $IMAGE_NAME:$IMAGE_TAG"
    echo "   .vsixファイルを手動で抽出: docker cp <container_id>:/app/cline-build.vsix ./"
fi

echo ""
echo "=== ビルド完了 ==="
echo ""
echo "次のコマンドでVS Codeにインストールできます:"
echo "  code --install-extension $OUTPUT_DIR/$VSIX_NAME"
echo ""
echo "または、Dockerイメージから直接情報を表示:"
echo "  docker run --rm $IMAGE_NAME:$IMAGE_TAG"
