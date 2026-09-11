/** Fixed cross-account gateway; no data, tokens or requests are persisted here. */
const PUBLIC_ORIGIN = 'https://leoinvesting.com';
const UPSTREAM_ORIGIN = 'https://leo.axio7.workers.dev';

export function publicLocation(value) {
  try {
    const location = new URL(value, UPSTREAM_ORIGIN);
    if (location.origin === UPSTREAM_ORIGIN) {
      return PUBLIC_ORIGIN + location.pathname + location.search + location.hash;
    }
  } catch { /* An invalid upstream header remains an upstream error. */ }
  return value;
}

export function publicCookie(value) {
  // Only the exact upstream host becomes a host-only cookie on the public host.
  // Do not split on commas: Expires attributes contain them.
  return value.replace(/;\s*domain\s*=\s*\.?leo\.axio7\.workers\.dev(?=\s*(?:;|$))/ig, '');
}

export function createProxy(upstreamFetch = fetch) {
  return {
    async fetch(request) {
      const incoming = new URL(request.url);
      if (incoming.origin !== PUBLIC_ORIGIN) {
        return new Response('Unknown host', { status: 421, headers: { 'cache-control': 'no-store' } });
      }
      const upstream = new URL(UPSTREAM_ORIGIN);
      upstream.pathname = incoming.pathname;
      upstream.search = incoming.search;
      // The browser consumes this code; fetching its static shell needs no code.
      if (upstream.pathname === '/strategy-auth/callback') upstream.search = '';
      const headers = new Headers(request.headers);
      for (const name of ['host', 'forwarded', 'x-forwarded-host', 'x-forwarded-proto', 'x-forwarded-for',
        'cf-access-jwt-assertion', 'cf-access-client-id', 'cf-access-client-secret']) headers.delete(name);
      headers.set('x-forwarded-host', incoming.host);
      headers.set('x-forwarded-proto', 'https');
      const outbound = new Request(upstream, {
        method: request.method,
        headers,
        body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
        redirect: 'manual',
        signal: request.signal,
        duplex: 'half',
      });
      try {
        // Redirects must reach the browser. Following them here could disclose
        // incoming authorization headers or cookies to an external destination.
        const response = await upstreamFetch(outbound);
        if (response.status === 101) return response;
        const resultHeaders = new Headers(response.headers);
        const location = resultHeaders.get('location');
        if (location) resultHeaders.set('location', publicLocation(location));
        const cookies = response.headers.getSetCookie();
        resultHeaders.delete('set-cookie');
        for (const cookie of cookies) resultHeaders.append('set-cookie', publicCookie(cookie));
        resultHeaders.set('x-leo-domain-proxy', 'v1');
        return new Response(request.method === 'HEAD' ? null : response.body, {
          status: response.status, statusText: response.statusText, headers: resultHeaders,
        });
      } catch {
        // No exception, URL, header, body or query-string logging.
        return new Response('Leo is temporarily unavailable. Please retry.', {
          status: 502, headers: { 'cache-control': 'no-store', 'content-type': 'text/plain; charset=utf-8' },
        });
      }
    },
  };
}

export default createProxy();
