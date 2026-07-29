# syntax=docker/dockerfile:1.7

FROM node:20-bookworm-slim AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-bookworm-slim AS builder
WORKDIR /app
ARG GIT_COMMIT=WORKTREE_UNCOMMITTED
RUN test "${#GIT_COMMIT}" -eq 40 \
    && case "$GIT_COMMIT" in *[!0-9a-f]*) exit 64;; esac
ENV GIT_COMMIT=$GIT_COMMIT \
    NEXT_TELEMETRY_DISABLED=1 \
    AXIO7_STANDALONE=true
ARG NEXT_PUBLIC_SITE_URL
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_PADDLE_CLIENT_TOKEN
ARG NEXT_PUBLIC_SENTRY_DSN
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL \
    NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL \
    NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY \
    NEXT_PUBLIC_PADDLE_CLIENT_TOKEN=$NEXT_PUBLIC_PADDLE_CLIENT_TOKEN \
    NEXT_PUBLIC_SENTRY_DSN=$NEXT_PUBLIC_SENTRY_DSN \
    NEXT_PUBLIC_POSTHOG_KEY=$NEXT_PUBLIC_POSTHOG_KEY \
    NEXT_PUBLIC_POSTHOG_HOST=$NEXT_PUBLIC_POSTHOG_HOST
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ARG GIT_COMMIT=WORKTREE_UNCOMMITTED
RUN test "${#GIT_COMMIT}" -eq 40 \
    && case "$GIT_COMMIT" in *[!0-9a-f]*) exit 64;; esac
LABEL org.opencontainers.image.revision=$GIT_COMMIT
ENV GIT_COMMIT=$GIT_COMMIT \
    AXIO7_SOURCE_COMMIT=$GIT_COMMIT \
    NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    PORT=3000

RUN groupadd --system --gid 1001 axio \
    && useradd --system --uid 1001 --gid axio --home-dir /app axio

COPY --from=builder --chown=axio:axio /app/public ./public
COPY --from=builder --chown=axio:axio /app/.next/standalone ./
COPY --from=builder --chown=axio:axio /app/.next/static ./.next/static

USER axio
EXPOSE 3000
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "server.js"]
