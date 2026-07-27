# syntax=docker/dockerfile:1.7

# 构建上下文必须是 axio7-model-review/source/，不是 quant_engine_rs/。
#
# src/ledger.rs:10 有 `include_str!("../../ledger/schema.sql")`，指向 crate 之外的
# 兄弟目录 source/ledger/。原本的 Dockerfile 只 COPY 了 Cargo.toml/Cargo.lock/src，
# 构建上下文也只是 crate 目录本身，那个文件根本不在上下文里，于是
#   error: couldn't read `src/../../ledger/schema.sql`: No such file or directory
# —— 这个镜像从来没有构建成功过。
#
# 构建命令：
#   docker build -f quant_engine_rs/Dockerfile axio7-model-review/source
FROM rust:1.88-bookworm AS builder
WORKDIR /build/quant_engine_rs

# 保持与仓库一致的相对布局，否则 include_str! 的 ../../ 会指错地方。
COPY ledger /build/ledger
COPY quant_engine_rs/Cargo.toml quant_engine_rs/Cargo.lock ./
COPY quant_engine_rs/src ./src
RUN cargo build --locked --release --bin quantd --bin quantctl

FROM debian:bookworm-slim AS runtime
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system axio \
    && useradd --system --gid axio --home-dir /app --shell /usr/sbin/nologin axio

WORKDIR /app
COPY --from=builder /build/quant_engine_rs/target/release/quantd /usr/local/bin/quantd
COPY --from=builder /build/quant_engine_rs/target/release/quantctl /usr/local/bin/quantctl
COPY --chown=axio:axio quant_engine_rs/configs ./configs
COPY --chown=axio:axio quant_engine_rs/configs/risk_policy.yaml ./risk_policy.yaml
# 注意：这里原本有 `COPY --chown=axio:axio data ./data`。
# `data/` 被 .gitignore 排除，clean clone 里根本不存在，任何从仓库出发的构建
# 都会在这一行失败。下面的 mkdir 已经创建了运行期需要的全部子目录，
# 所以这行 COPY 既是多余的也是破坏性的，已移除。
# 如果确实需要随镜像分发种子数据，请放到一个被显式跟踪的路径（例如 seed/）再 COPY。
COPY --chown=axio:axio quant_engine_rs/container-entrypoint.sh /usr/local/bin/axio-entrypoint

RUN chmod 0555 /usr/local/bin/quantd /usr/local/bin/quantctl /usr/local/bin/axio-entrypoint \
    && mkdir -p /app/data/live/options /app/data/state /app/data/reports \
    && chown -R axio:axio /app/data/live /app/data/state /app/data/reports

USER axio
ENV PORT=8001 \
    RUST_LOG=axio_quant_engine=info,tower_http=info
EXPOSE 8001
HEALTHCHECK --interval=20s --timeout=3s --start-period=30s --retries=3 \
  CMD curl --fail --silent "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/axio-entrypoint"]
