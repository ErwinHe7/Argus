function routeSuffix(pathname: string, functionName: string): string {
  const candidates = [
    `/functions/v1/${functionName}`,
    `/${functionName}`,
  ];
  for (const prefix of candidates) {
    if (pathname === prefix) return "/";
    if (pathname.startsWith(`${prefix}/`)) return pathname.slice(prefix.length);
  }
  return pathname;
}

/** Preserve method, headers, and the exact body stream while removing only the
 * Supabase gateway's function mount prefix from the portable Hono request. */
export function rewriteSupabaseFunctionRequest(
  request: Request,
  functionName: string,
): Request {
  const url = new URL(request.url);
  url.pathname = routeSuffix(url.pathname, functionName);
  return new Request(url, request);
}
