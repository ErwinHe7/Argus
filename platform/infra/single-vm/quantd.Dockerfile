# syntax=docker/dockerfile:1.7

FROM rust:1.97.1-bookworm AS builder
WORKDIR /build
ARG GIT_COMMIT=WORKTREE_UNCOMMITTED
RUN test "${#GIT_COMMIT}" -eq 40 \
    && case "$GIT_COMMIT" in *[!0-9a-f]*) exit 64;; esac
ENV GIT_COMMIT=$GIT_COMMIT

COPY quant_engine_rs/Cargo.toml quant_engine_rs/Cargo.lock ./
COPY ledger/schema.sql /ledger/schema.sql
COPY quant_engine_rs/src ./src
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/build/target \
    cargo build --locked --release --bin quantd --bin quantctl \
    && install -D -m 0555 target/release/quantd /out/quantd \
    && install -D -m 0555 target/release/quantctl /out/quantctl

FROM debian:bookworm-slim AS runtime
ARG GIT_COMMIT=WORKTREE_UNCOMMITTED
RUN test "${#GIT_COMMIT}" -eq 40 \
    && case "$GIT_COMMIT" in *[!0-9a-f]*) exit 64;; esac
LABEL org.opencontainers.image.revision=$GIT_COMMIT
RUN apt-get update \
    && apt-get install --yes --no-install-recommends bash ca-certificates curl tini util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system axio \
    && useradd --system --gid axio --home-dir /app --shell /usr/sbin/nologin axio

WORKDIR /app
COPY --from=builder /out/quantd /usr/local/bin/quantd
COPY --from=builder /out/quantctl /usr/local/bin/quantctl
COPY --chown=axio:axio quant_engine_rs/configs ./configs
COPY --chown=axio:axio quant_engine_rs/configs/risk_policy.yaml ./risk_policy.yaml
COPY --chown=axio:axio quant_engine_rs/data ./data
COPY --chown=axio:axio quant_engine_rs/container-entrypoint.sh /usr/local/bin/axio-entrypoint

RUN sed -i 's/\r$//' /usr/local/bin/axio-entrypoint \
    && chmod 0555 /usr/local/bin/quantd /usr/local/bin/quantctl /usr/local/bin/axio-entrypoint \
    && test -r /app/data/models/universe/registry.json \
    && for artifact in SPX QQQ NVDA AAPL MU SOXX NBIS BE IGV; do \
        test -r "/app/data/models/universe/${artifact}.frozen.json"; \
    done \
    && mkdir -p /app/data/live/options /app/data/state /app/data/reports \
        /app/data/rights /app/data/evidence /app/data/promotion \
        /app/data/calibration /app/data/models \
    && ln -sfn ../promotion/predictor_promotion_latest.json \
        /app/data/models/predictor_promotion_latest.json \
    && chown -R axio:axio /app/data/live /app/data/state /app/data/reports \
        /app/data/rights /app/data/evidence /app/data/promotion \
        /app/data/calibration \
    && chown -R root:root /app/data/models \
    && chmod -R a-w /app/data/models

USER axio
ENV GIT_COMMIT=$GIT_COMMIT \
    PORT=8001 \
    RUST_LOG=axio_quant_engine=info,tower_http=info
EXPOSE 8001
HEALTHCHECK --interval=20s --timeout=3s --start-period=30s --retries=3 \
  CMD curl --fail --silent "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/axio-entrypoint"]
