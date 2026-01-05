# Cline拡張機能のDockerビルド

このドキュメントでは、Cline VS Code拡張機能をDockerを使用してビルドする方法について説明します。

## 概要

Dockerを使用することで、一貫した環境でCline拡張機能をビルドし、`.vsix`ファイルを生成できます。これにより、異なるシステム間でのビルド環境の差異を排除し、再現性のあるビルドが可能になります。

## 前提条件

- Dockerがインストールされていること
- 十分なディスク空き容量（約2GB）
- インターネット接続（依存関係のダウンロード用）

## ファイル構成

```
.
├── Dockerfile              # Dockerビルド設定
├── docker-build.sh        # ビルドスクリプト
├── DOCKER-BUILD-README.md # このファイル
└── docker-output/         # 生成された.vsixファイルの出力先
```

## ビルド方法

### 方法1: ビルドスクリプトを使用（推奨）

```bash
# スクリプトに実行権限を付与（初回のみ）
chmod +x docker-build.sh

# 基本的なビルド
./docker-build.sh

# タグを指定してビルド
./docker-build.sh -t v1.0.0

# 出力ディレクトリを変更
./docker-build.sh -o ./builds

# ヘルプを表示
./docker-build.sh --help
```

### 方法2: Dockerコマンドを直接使用

```bash
# Dockerイメージのビルド
docker build -t cline-builder:latest .

# コンテナを実行して情報を表示
docker run --rm cline-builder:latest

# .vsixファイルを手動で抽出
docker run -d --name cline-temp cline-builder:latest
docker cp cline-temp:/app/cline-build.vsix .
docker rm cline-temp
```

## ビルドスクリプトのオプション

| オプション | 説明 | デフォルト値 |
|-----------|------|-------------|
| `-h, --help` | ヘルプメッセージを表示 | - |
| `-t, --tag TAG` | Dockerイメージのタグ | `latest` |
| `-o, --output DIR` | 出力ディレクトリ | `./docker-output` |
| `-n, --name NAME` | .vsixファイル名 | `cline-docker-build.vsix` |
| `--no-extract` | .vsixファイルを抽出しない | `false` |
| `--skip-build` | Dockerビルドをスキップ | `false` |

## ビルドプロセスの詳細

Dockerビルドは以下のステップで実行されます：

1. **ベースイメージ**: Node.js 20 Alpine
2. **依存関係のインストール**:
   - システムツール（git, python3, make, g++）
   - npmパッケージ（ルートとwebview-uiの両方）
3. **Protobufのコンパイル**: `npm run protos`
4. **タイプチェックとリンター**: `npm run check-types`、`npm run lint`
5. **webview-uiのビルド**: `npm run build:webview`
6. **拡張機能のビルド**: `npm run package`
7. **.vsixファイルの生成**: `vsce package`

## 生成されたファイルのインストール

ビルドが完了すると、`docker-output/`ディレクトリに`.vsix`ファイルが生成されます。以下のコマンドでVS Codeにインストールできます：

```bash
code --install-extension docker-output/cline-docker-build.vsix
```

または、VS Code内で：
1. `Ctrl+Shift+P`（Windows/Linux）または `Cmd+Shift+P`（Mac）を押す
2. "Extensions: Install from VSIX..."を選択
3. 生成された`.vsix`ファイルを選択

## GitHub Actionsとの比較

このDockerビルドは、`.github/workflows/publish.yml`で定義されているGitHub Actionsワークフローと同様のビルドプロセスを実行しますが、以下の点が異なります：

- **環境変数**: 本番環境用の環境変数が設定されています
- **キャッシュ**: Dockerレイヤーキャッシュを利用
- **依存関係**: 毎回クリーンな環境でインストール

## トラブルシューティング

### メモリ不足エラー

Dockerビルド中にメモリ不足が発生する場合：

```bash
# Dockerのメモリ制限を増やす（Docker Desktopの場合）
# または
docker build --memory=4g -t cline-builder:latest .
```

### ネットワークエラー

プロキシ環境下でビルドする場合：

```bash
# Dockerデーモンのプロキシ設定を確認
# または
docker build --build-arg HTTP_PROXY=http://proxy.example.com:8080 -t cline-builder:latest .
```

### ビルド時間の短縮

既存のイメージがある場合：

```bash
./docker-build.sh --skip-build
```

## カスタマイズ

### 環境変数の変更

Dockerfile内の環境変数を変更することで、ビルド設定を調整できます：

```dockerfile
# テレメトリの有効/無効
ENV OTEL_TELEMETRY_ENABLED=true

# OpenTelemetryエンドポイントの変更
ENV OTEL_EXPORTER_OTLP_ENDPOINT=https://your-otel-endpoint:4317
```

### ビルド引数の使用

Dockerビルド時に引数を渡す：

```bash
docker build \
  --build-arg NODE_VERSION=18 \
  --build-arg CLINE_ENVIRONMENT=staging \
  -t cline-builder:custom .
```

## ライセンス

このDockerビルド設定は、ClineプロジェクトのApache-2.0ライセンスの下で提供されています。
