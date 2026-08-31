type AuthSiteEnvironment = {
  NODE_ENV?: string;
  AXIO7_SITE_URL?: string;
  NEXT_PUBLIC_SITE_URL?: string;
};

function httpOrigin(value: string | null | undefined): string | null {
  if (!value) return null;

  try {
    const parsed = new URL(value);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return null;
    }
    return parsed.origin;
  } catch {
    return null;
  }
}

function forwardedOrigin(request: Request): string | null {
  const host = request.headers.get('x-forwarded-host')?.split(',')[0]?.trim();
  const proto = request.headers.get('x-forwarded-proto')?.split(',')[0]?.trim();
  if (!host || (proto !== 'http' && proto !== 'https')) {
    return null;
  }
  return httpOrigin(`${proto}://${host}`);
}

/**
 * Resolve the trusted browser-facing origin for an auth redirect.
 *
 * Next.js standalone builds can construct request.url from their bind address
 * (for example https://0.0.0.0:3000) behind a TLS-terminating reverse proxy.
 * Production auth redirects must therefore use the configured public origin,
 * never that internal request origin.
 */
export function authRedirectOrigin(
  request: Request,
  environment: AuthSiteEnvironment = process.env
): string {
  const requestOrigin = httpOrigin(request.url);
  if (!requestOrigin) {
    throw new Error('Auth request URL must have a valid HTTP(S) origin.');
  }

  const configuredValue =
    environment.AXIO7_SITE_URL?.trim() ||
    environment.NEXT_PUBLIC_SITE_URL?.trim();
  const configuredOrigin = httpOrigin(configuredValue);

  if (configuredValue && !configuredOrigin) {
    throw new Error('AXIO7_SITE_URL must have a valid HTTP(S) origin.');
  }

  if (environment.NODE_ENV === 'production') {
    if (!configuredOrigin) {
      throw new Error('AXIO7_SITE_URL is required for production auth redirects.');
    }
    return configuredOrigin;
  }

  // Preserve localhost during development, while still supporting a local
  // production-like proxy whose forwarded origin matches the configured site.
  if (configuredOrigin && forwardedOrigin(request) === configuredOrigin) {
    return configuredOrigin;
  }

  return requestOrigin;
}
