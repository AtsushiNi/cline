# Cline Extension Docker Build
# このDockerfileはCline VS Code拡張機能をビルドし、.vsixファイルを生成します

# マルチステージビルドを使用
# ステージ1: ビルド環境
FROM node:20-bullseye AS builder

# 必要なツールのインストール
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    make \
    g++ \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリの設定
WORKDIR /app

# パッケージファイルのコピー
COPY package*.json ./
COPY webview-ui/package*.json ./webview-ui/

# 依存関係のインストール（オプション依存関係を含む）
RUN npm install --include=optional

# webview-uiの依存関係のインストール
RUN cd webview-ui && npm install --include=optional

# ソースコードのコピー
COPY . .

# Protobufのコンパイル（システムのprotocを使用）
RUN PROTOC=/usr/bin/protoc npm run protos

# タイプチェックとリンターの実行
RUN npm run check-types
RUN npm run lint

# webview-uiのビルド
RUN npm run build:webview

# 拡張機能のビルド（プロダクションモード）
RUN npm run package

# .vsixファイルの生成
# 環境変数を設定（GitHub Actionsのワークフローを参考）
ENV CLINE_ENVIRONMENT=production
ENV TELEMETRY_SERVICE_API_KEY=dummy_key_for_build
ENV ERROR_SERVICE_API_KEY=dummy_key_for_build
ENV OTEL_TELEMETRY_ENABLED=false
ENV OTEL_LOGS_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=otlp
ENV OTEL_EXPORTER_OTLP_PROTOCOL=grpc
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
ENV OTEL_EXPORTER_OTLP_HEADERS=""

# vsceツールのインストール
RUN npm install -g @vscode/vsce

# .vsixファイルの生成
RUN vsce package --allow-package-secrets sendgrid --out "cline-build.vsix"

# ステージ2: 軽量なランタイムイメージ
FROM alpine:latest AS runtime

# 作業ディレクトリの設定
WORKDIR /app

# ビルドステージから生成されたファイルをコピー
COPY --from=builder /app/cline-build.vsix .
COPY --from=builder /app/package.json .

# メタデータ表示用スクリプト
RUN echo '#!/bin/sh' > /app/show-info.sh && \
    echo 'echo "Cline Extension Build Information"' >> /app/show-info.sh && \
    echo 'echo "================================"' >> /app/show-info.sh && \
    echo 'cat /app/package.json | grep -E '"'"'"name"|"version"|"description"'"'"'' >> /app/show-info.sh && \
    echo 'echo ""' >> /app/show-info.sh && \
    echo 'echo "Generated .vsix file: cline-build.vsix"' >> /app/show-info.sh && \
    echo 'ls -lh /app/cline-build.vsix' >> /app/show-info.sh && \
    chmod +x /app/show-info.sh

# エントリーポイントの設定
ENTRYPOINT ["/app/show-info.sh"]
