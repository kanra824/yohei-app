# リリース用バイナリをビルドするためのマルチステージ Dockerfile
# ビルダー段階
FROM rust:1-bullseye as builder
WORKDIR /usr/src/yohei-app

# 依存関係のキャッシュを狙ってまずマニフェストのみコピーしてフェッチします
COPY Cargo.toml Cargo.lock ./
# ソース全体をまだコピーせずに依存を解決するためのダミー main を作成
RUN mkdir -p src && echo 'fn main() {}' > src/main.rs
RUN cargo build --release

# ソース全体をコピーしてリリースビルドを行う
COPY . .
# Touch src/main.rs を更新して cargo に変更を認識させる
RUN touch src/main.rs && cargo build --release -p yohei-app

# 実行用ステージ（ランタイム）
FROM debian:bookworm-slim
# ランタイムに必要な最小限のパッケージをインストール（証明書など）
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# ビルダーからバイナリをコピー
COPY --from=builder /usr/src/yohei-app/target/release/yohei-app /usr/local/bin/yohei-app

# 非特権ユーザーを作成して実行ユーザーを切り替える
RUN useradd -m appuser && chown appuser:appuser /usr/local/bin/yohei-app
USER appuser

# コンテナで公開するポート
EXPOSE 8080
# 実行時の環境変数（ログレベル等）
ENV RUST_LOG=info
# デフォルトの実行コマンド
CMD ["/usr/local/bin/yohei-app"]
