const BUILD_REVISION_HEADER = "x-argus-build-revision";

export function withBuildRevisionHeader(
  handler: (request: Request) => Response | Promise<Response>,
  buildRevision = Deno.env.get("ARGUS_BUILD_REVISION") ?? "local",
): (request: Request) => Promise<Response> {
  return async (request) => {
    const response = await handler(request);
    const headers = new Headers(response.headers);
    headers.set(BUILD_REVISION_HEADER, buildRevision);
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  };
}
