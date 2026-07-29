const INTERNAL_REDIRECT_BASE = 'https://axio7-internal.invalid';

/**
 * Return a same-origin path suitable for a redirect Location header.
 *
 * A leading slash alone is not sufficient: values such as `//example.com`
 * and `/\example.com` are interpreted by URL parsers as cross-origin URLs.
 */
export function safeInternalRedirectPath(
  value: string | null | undefined
): string {
  if (!value || !value.startsWith('/') || value.startsWith('//')) {
    return '/';
  }

  try {
    const resolved = new URL(value, INTERNAL_REDIRECT_BASE);
    if (resolved.origin !== INTERNAL_REDIRECT_BASE) {
      return '/';
    }

    return `${resolved.pathname}${resolved.search}${resolved.hash}`;
  } catch {
    return '/';
  }
}
