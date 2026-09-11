/** Keep the deployed application and its bindings behind two homepage routes. */
type OriginalWorker = {
  fetch(request: Request, env: CloudflareEnv, context: ExecutionContext): Promise<Response>;
};

const legacyLayoutScript = '/_next/static/chunks/app/layout-17f5d2848155fa3a.js';

export function createResearchHomeWorker(originalWorker: OriginalWorker): OriginalWorker {
  return {
    async fetch(request, env, context) {
      const url = new URL(request.url);
      if (url.pathname === '/app/research-desk/data/event-radar.json') {
        const headers = { 'content-type': 'application/json', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
        if (request.method !== 'GET' && request.method !== 'HEAD') return new Response('{"error":"read_only"}', { status: 405, headers: { ...headers, allow: 'GET, HEAD' } });
        const feed = (env as CloudflareEnv & { EVENT_RADAR?: { fetch(request: Request): Promise<Response> } }).EVENT_RADAR;
        if (!feed) return new Response(request.method === 'HEAD' ? null : '{"error":"radar_not_connected"}', { status: 503, headers });
        try {
          const response = await feed.fetch(new Request('https://event-radar/radar', { signal: request.signal }));
          return new Response(request.method === 'HEAD' ? null : response.body, { status: response.status, headers });
        } catch {
          return new Response(request.method === 'HEAD' ? null : '{"error":"radar_unavailable"}', { status: 503, headers });
        }
      }
      if (url.pathname === '/app/research-desk/data/shortlist-feed/current.json') {
        const headers = { 'content-type': 'application/json', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
        if (request.method !== 'GET' && request.method !== 'HEAD') return new Response('{"error":"read_only"}', { status: 405, headers: { ...headers, allow: 'GET, HEAD' } });
        const feed = (env as CloudflareEnv & { SHORTLIST_FEED?: { fetch(request: Request): Promise<Response> } }).SHORTLIST_FEED;
        if (!feed) return new Response(request.method === 'HEAD' ? null : '{"error":"publisher_not_connected"}', { status: 503, headers });
        try {
          // Only read published public evidence. Never forward cookies, auth,
          // query strings, caller URLs, or a write method to the publisher.
          const response = await feed.fetch(new Request('https://shortlist-feed/publication', { signal: request.signal }));
          return new Response(request.method === 'HEAD' ? null : response.body, { status: response.status, headers });
        } catch {
          return new Response(request.method === 'HEAD' ? null : '{"error":"publisher_unavailable"}', { status: 503, headers });
        }
      }
      if (request.method === 'GET' || request.method === 'HEAD') {
        if (url.pathname === '/' || url.pathname === '/strategy-auth/callback') {
          // Fetch the directory path so the Assets binding does not canonicalize
          // index.html with a redirect. The browser stays at the public root.
          url.pathname = '/app/research-desk/';
          // The callback page needs the code in the browser only; never forward
          // single-use auth codes to the asset service or an intermediary cache.
          if (new URL(request.url).pathname === '/strategy-auth/callback') {
            url.search = '';
            const response = await env.ASSETS.fetch(new Request(url, request));
            const headers = new Headers(response.headers);
            headers.set('Cache-Control', 'no-store');
            headers.set('Referrer-Policy', 'no-referrer');
            return new Response(response.body, { status: response.status, headers });
          }
          return env.ASSETS.fetch(new Request(url, request));
        }
        if (url.pathname === '/original') {
          url.pathname = '/original/';
          return Response.redirect(url.toString(), 308);
        }
        if (url.pathname === '/original/') {
          url.pathname = '/';
          const response = await originalWorker.fetch(new Request(url, request), env, context);
          if (request.method === 'GET' && response.headers.get('content-type')?.includes('text/html')) {
            // Existing visitors may have the immutable pre-alias chunk cached.
            // Only the preserved homepage requests this guarded alias revision.
            return new HTMLRewriter().on(`script[src="${legacyLayoutScript}"]`, {
              element(element) {
                element.setAttribute('src', `${legacyLayoutScript}?leo-home-alias=1`);
              },
            }).transform(response);
          }
          return response;
        }
      }
      // Preserve the original Request, including methods, bodies, authentication,
      // query strings, and signal for all application and API traffic.
      return originalWorker.fetch(request, env, context);
    },
  };
}
