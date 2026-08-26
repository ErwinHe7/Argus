import { createApp } from "./app.ts";
import { validateBindings, type Bindings } from "./config/env.ts";
import { runQueue } from "./jobs/queue-runtime.ts";
import { runScheduled } from "./jobs/scheduled.ts";

function resolveBindings(environment: unknown): Bindings | undefined {
  try {
    return validateBindings(environment);
  } catch {
    console.error("Ritual Worker runtime configuration validation failed.");
    return undefined;
  }
}

function configurationUnavailable(): Response {
  return Response.json(
    {
      type: "https://api.just-build-this.app/problems/service-unavailable",
      title: "Service unavailable",
      status: 503,
      code: "runtime_configuration_unavailable",
    },
    {
      status: 503,
      headers: {
        "cache-control": "no-store",
        "content-type": "application/problem+json",
        "x-content-type-options": "nosniff",
      },
    },
  );
}

function secureAdminAsset(response: Response, pathname: string): Response {
  const headers = new Headers(response.headers);
  headers.set("x-content-type-options", "nosniff");
  headers.set("x-frame-options", "DENY");
  headers.set("referrer-policy", "no-referrer");
  headers.set(
    "content-security-policy",
    "default-src 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'; connect-src 'self' https://*.auth0.com; img-src 'self' data:; font-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'",
  );
  headers.set(
    "cache-control",
    pathname === "/" ||
      pathname.endsWith(".html") ||
      response.headers.get("content-type")?.toLowerCase().includes("text/html")
      ? "no-store"
      : "public, max-age=31536000, immutable",
  );
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

const app = createApp();

const worker = {
  fetch(request, environment, executionContext) {
    const bindings = resolveBindings(environment);
    if (bindings === undefined) return configurationUnavailable();
    const url = new URL(request.url);
    if (
      bindings.ADMIN_UI_HOST !== undefined &&
      url.hostname === bindings.ADMIN_UI_HOST
    ) {
      if (url.pathname.startsWith("/v1/"))
        return app.fetch(request, bindings, executionContext);
      if (bindings.ADMIN_ASSETS === undefined)
        return new Response("Admin dashboard unavailable", { status: 503 });
      return bindings.ADMIN_ASSETS.fetch(request).then((response) =>
        secureAdminAsset(response, url.pathname),
      );
    }
    return app.fetch(request, bindings, executionContext);
  },
  async scheduled(controller, environment, executionContext) {
    const bindings = resolveBindings(environment);
    if (bindings === undefined) return;
    executionContext.waitUntil(runScheduled(controller, bindings));
  },
  async queue(batch, environment, executionContext) {
    const bindings = resolveBindings(environment);
    if (bindings === undefined) return;
    executionContext.waitUntil(runQueue(batch, bindings));
  },
} satisfies ExportedHandler<Bindings>;

export default worker;
