import { withSentryConfig } from '@sentry/nextjs';

const sentryEnabled = Boolean(
  process.env.SENTRY_DSN?.trim() || process.env.NEXT_PUBLIC_SENTRY_DSN?.trim()
);

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    return [
      // Flutter's web build lives in public/app. Next serves the files inside
      // that folder, but it does not resolve its index.html for /app itself.
      { source: '/app', destination: '/app/index.html' },
    ];
  },
  env: {
    // Make the build-time choice explicit so an unconfigured preview does not
    // carry the Sentry server SDK into a size-constrained edge bundle.
    AXIO7_SENTRY_BUNDLED: sentryEnabled ? 'true' : 'false',
  },
  // Keep validation/dev instances from racing over `.next` when the operator
  // already has a long-running dashboard process. Production keeps `.next`
  // unless an explicit server-side build directory is supplied.
  distDir: process.env.AXIO7_NEXT_DIST_DIR?.trim() || '.next',
  // Vercel keeps its native output. The self-hosted container opts into the
  // minimal standalone Node server at build time.
  output: process.env.AXIO7_STANDALONE === 'true' ? 'standalone' : undefined,
  images: {
    // The single-VM runtime is intentionally read-only. Serve local and remote
    // image URLs directly there instead of requiring a writable optimizer
    // cache and the optional native `sharp` package inside the web container.
    unoptimized: process.env.AXIO7_STANDALONE === 'true',
    remotePatterns: [
      { protocol: 'https', hostname: '**' },
    ],
  },
};

export default sentryEnabled
  ? withSentryConfig(nextConfig, {
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      silent: true,
      widenClientFileUpload: true,
      disableLogger: true,
      hideSourceMaps: true,
    })
  : nextConfig;
