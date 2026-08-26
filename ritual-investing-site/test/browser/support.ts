import { Buffer } from "node:buffer";
import { readFile } from "node:fs/promises";
import { extname, resolve, sep } from "node:path";

import type { Page, Route } from "@playwright/test";

export const LANDING_ORIGIN = "https://just-build-this.app/";
export const DEMO_ORIGIN = "https://demo.just-build-this.app/";
const TURNSTILE_ORIGIN = "https://challenges.cloudflare.com/";
const SITE_ROOT = resolve(import.meta.dirname, "../..");
const LANDING_ROOT = resolve(SITE_ROOT, "dist/landing");
const DEMO_ROOT = resolve(SITE_ROOT, "dist/demo");
const SITE_KEY = "0x4AAAAAAAsyntheticBrowserSiteKey";

const CONTENT_TYPES: Record<string, string> = {
  ".bin": "application/octet-stream",
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".ttf": "font/ttf",
  ".wasm": "application/wasm",
};

type DemoMode = "mock-ready" | "mock-silent" | "real";
type ApiResponse = { status: number; body: Record<string, unknown> };

export type LocalSurface = {
  requests: string[];
  waitlistBodies: unknown[];
};

type LocalSurfaceOptions = {
  demo?: DemoMode;
  waitlist?: ApiResponse | ((body: unknown) => ApiResponse);
};

async function globalHeaders(root: string): Promise<Record<string, string>> {
  const lines = (await readFile(resolve(root, "_headers"), "utf8")).split(/\r?\n/);
  const headers: Record<string, string> = {};
  let global = false;
  for (const line of lines) {
    if (line === "/*") {
      global = true;
      continue;
    }
    if (global && line === "") break;
    if (!global) continue;
    const match = /^  ([^:]+):\s*(.*)$/.exec(line);
    if (match?.[1] !== undefined && match[2] !== undefined) {
      headers[match[1].toLowerCase()] = match[2];
    }
  }
  return headers;
}

function safeAssetPath(root: string, pathname: string): string | null {
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  const relative = decoded === "/" ? "index.html" : decoded.replace(/^\/+/, "");
  if (relative === "_headers" || relative.includes("\0")) return null;
  const candidate = resolve(root, relative.endsWith("/") ? `${relative}index.html` : relative);
  return candidate === root || candidate.startsWith(`${root}${sep}`) ? candidate : null;
}

async function fulfillStatic(route: Route, root: string, injectSiteKey: boolean): Promise<void> {
  const requestUrl = new URL(route.request().url());
  let path = safeAssetPath(root, requestUrl.pathname);
  if (path === null) {
    await route.fulfill({ status: 404, body: "Not found" });
    return;
  }
  let body: Buffer;
  try {
    body = await readFile(path);
  } catch {
    if (!extname(path)) path = resolve(path, "index.html");
    try {
      body = await readFile(path);
    } catch {
      await route.fulfill({ status: 404, body: "Not found" });
      return;
    }
  }
  if (injectSiteKey && path === resolve(root, "index.html")) {
    body = Buffer.from(
      new TextDecoder().decode(body).replace(
        'data-turnstile-site-key=""',
        `data-turnstile-site-key="${SITE_KEY}"`,
      ),
      "utf8",
    );
  }
  await route.fulfill({
    status: 200,
    headers: {
      ...(await globalHeaders(root)),
      "content-type": CONTENT_TYPES[extname(path).toLowerCase()] ?? "application/octet-stream",
    },
    body,
  });
}

function mockDemoDocument(): string {
  return `<!doctype html><html lang="en"><head><title>Ritual Investing Demo</title></head><body>
    <main><h1>Ritual Investing Demo</h1><button type="button">Daily Ritual</button></main>
    <script src="/mock-demo.js"></script>
  </body></html>`;
}

const mockDemoScript = `const identity = new URL(location.href).searchParams;
setTimeout(() => parent.postMessage({
  source: "ritual-investing-demo",
  type: "ritual-demo-ready",
  protocolVersion: 2,
  environment: identity.get("environment"),
  attemptId: identity.get("attempt")
}, "https://just-build-this.app"), 100);`;

const turnstileMock = `globalThis.turnstile = {
  render(target, options) {
    target.dataset.mockTurnstile = "local";
    setTimeout(() => options.callback("synthetic-browser-token"), 0);
    return "local-widget";
  },
  reset() {}
};`;

export async function installLocalProductionSurface(
  page: Page,
  options: LocalSurfaceOptions = {},
): Promise<LocalSurface> {
  const surface: LocalSurface = { requests: [], waitlistBodies: [] };
  page.on("request", (request) => surface.requests.push(request.url()));

  await page.route(`${LANDING_ORIGIN}**`, (route) => fulfillStatic(route, LANDING_ROOT, true));
  await page.route(`${DEMO_ORIGIN}**`, async (route) => {
    const mode = options.demo ?? "mock-ready";
    if (mode === "real") {
      await fulfillStatic(route, DEMO_ROOT, false);
      return;
    }
    const headers = await globalHeaders(DEMO_ROOT);
    if (new URL(route.request().url()).pathname === "/mock-demo.js") {
      await route.fulfill({
        status: 200,
        headers: { ...headers, "content-type": "text/javascript; charset=utf-8" },
        body: mockDemoScript,
      });
      return;
    }
    await route.fulfill({
      status: 200,
      headers: { ...headers, "content-type": "text/html; charset=utf-8" },
      body: mode === "mock-ready"
        ? mockDemoDocument()
        : "<!doctype html><title>Silent local demo</title>",
    });
  });
  await page.route(`${TURNSTILE_ORIGIN}**`, (route) => route.fulfill({
    status: 200,
    headers: { "content-type": "text/javascript; charset=utf-8" },
    body: turnstileMock,
  }));
  await page.route(`${LANDING_ORIGIN}api/waitlist`, async (route) => {
    let body: unknown = null;
    try { body = route.request().postDataJSON(); } catch { /* browser request shape is asserted by the caller */ }
    surface.waitlistBodies.push(body);
    const configured = typeof options.waitlist === "function"
      ? options.waitlist(body)
      : options.waitlist ?? { status: 202, body: { code: "accepted" } };
    await route.fulfill({
      status: configured.status,
      headers: { "content-type": "application/json", "cache-control": "no-store" },
      body: JSON.stringify(configured.body),
    });
  });
  return surface;
}
