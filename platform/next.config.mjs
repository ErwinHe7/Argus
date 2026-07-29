import { withSentryConfig } from '@sentry/nextjs';

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
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

export default withSentryConfig(nextConfig, {
  org: process.env.SENTRY_ORG,
  project: process.env.SENTRY_PROJECT,
  silent: true,
  widenClientFileUpload: true,
  disableLogger: true,
  hideSourceMaps: true,
});
