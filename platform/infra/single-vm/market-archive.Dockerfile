# syntax=docker/dockerfile:1.7

FROM python:3.13-slim-bookworm
ARG GIT_COMMIT=WORKTREE_UNCOMMITTED
RUN test "${#GIT_COMMIT}" -eq 40 \
    && case "$GIT_COMMIT" in *[!0-9a-f]*) exit 64;; esac
LABEL org.opencontainers.image.revision=$GIT_COMMIT

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates tini \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "psycopg[binary]>=3.2,<4" \
    && groupadd --system axio \
    && useradd --system --gid axio --home-dir /app --shell /usr/sbin/nologin axio

WORKDIR /app
COPY --chown=axio:axio intraday_quant/src ./src
COPY --chown=axio:axio infra/market-data/postgres/schema.sql ./schema.sql

USER axio
ENV GIT_COMMIT=$GIT_COMMIT \
    PYTHONPATH=/app/src \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "python", "-m", "intraday_quant.storage.live_postgres_archive"]
