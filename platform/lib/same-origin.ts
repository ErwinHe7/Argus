import type { NextRequest } from 'next/server';

function canonicalOrigin(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    return new URL(value).origin;
  } catch {
    return null;
  }
}

/**
 * Accept browser mutations only from the request origin or the configured
 * public site. The configured origin is required behind a TLS-terminating
 * reverse proxy, where Next.js can see the internal HTTP scheme.
 */
export function isSameOriginRequest(request: NextRequest): boolean {
  const suppliedOrigin = canonicalOrigin(request.headers.get('origin'));
  if (!request.headers.has('origin')) return true;
  if (!suppliedOrigin) return false;

  const allowedOrigins = new Set(
    [
      canonicalOrigin(request.nextUrl.origin),
      canonicalOrigin(request.url),
      canonicalOrigin(process.env.NEXT_PUBLIC_SITE_URL),
    ].filter((value): value is string => value !== null)
  );

  return allowedOrigins.has(suppliedOrigin);
}
