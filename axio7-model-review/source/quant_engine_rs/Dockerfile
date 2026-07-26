# syntax=docker/dockerfile:1.7

FROM rust:1.88-bookworm AS builder
WORKDIR /build

COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --locked --release --bin quantd --bin quantctl

FROM debian:bookworm-slim AS runtime
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system axio \
    && useradd --system --gid axio --home-dir /app --shell /usr/sbin/nologin axio

WORKDIR /app
COPY --from=builder /build/target/release/quantd /usr/local/bin/quantd
COPY --from=builder /build/target/release/quantctl /usr/local/bin/quantctl
COPY --chown=axio:axio configs ./configs
COPY --chown=axio:axio configs/risk_policy.yaml ./risk_policy.yaml
COPY --chown=axio:axio data ./data
COPY --chown=axio:axio container-entrypoint.sh /usr/local/bin/axio-entrypoint

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
