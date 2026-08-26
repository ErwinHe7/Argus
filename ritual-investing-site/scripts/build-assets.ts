import { createHash } from "node:crypto";
import {
  copyFile,
  cp,
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

export const MAX_ASSET_BYTES = 25 * 1024 * 1024;

type DeploymentEnvironment = "production" | "beta";

const HOSTS = {
  production: {
    landing: "https://just-build-this.app",
    demo: "https://demo.just-build-this.app",
  },
  beta: {
    landing: "https://beta.just-build-this.app",
    demo: "https://demo-beta.just-build-this.app",
  },
} as const;

const NOINDEX = "X-Robots-Tag: noindex, nofollow, noarchive";
const TURNSTILE_SITE_KEY_ATTRIBUTE = 'data-turnstile-site-key=""';

export function injectTurnstileSiteKey(html: string, siteKey: string): string {
  if (!/^[A-Za-z0-9_-]{20,128}$/.test(siteKey)) {
    throw new Error("The Turnstile site key has an invalid public-key shape.");
  }
  if (html.split(TURNSTILE_SITE_KEY_ATTRIBUTE).length !== 2) {
    throw new Error("The landing must contain exactly one empty Turnstile site-key seam.");
  }
  return html.replace(TURNSTILE_SITE_KEY_ATTRIBUTE, `data-turnstile-site-key="${siteKey}"`);
}

function entryCacheRules(paths: readonly string[]): string {
  return paths.map((path) => `${path}\n  Cache-Control: no-cache, no-store, must-revalidate`).join("\n\n");
}

export function renderLandingHeaders(environment: DeploymentEnvironment): string {
  const peer = HOSTS[environment];
  const csp = [
    "default-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    `frame-src ${peer.demo} https://challenges.cloudflare.com`,
    "script-src 'self' https://challenges.cloudflare.com",
    "style-src 'self'",
    "font-src 'self'",
    "img-src 'self'",
    "connect-src 'self' https://challenges.cloudflare.com",
    "object-src 'none'",
    "media-src 'none'",
    "manifest-src 'none'",
    "worker-src 'none'",
    "upgrade-insecure-requests",
  ].join("; ");
  const indexPolicy = environment === "beta" ? `\n  ${NOINDEX}` : "";
  return `/*
  Content-Security-Policy: ${csp}
  Permissions-Policy: accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
  Referrer-Policy: strict-origin-when-cross-origin
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Resource-Policy: same-origin${indexPolicy}

${entryCacheRules(["/", "/index.html", "/privacy/waitlist", "/privacy/waitlist/", "/privacy/waitlist/index.html", "/landing.js", "/styles.css", "/robots.txt", "/sitemap.xml"])}

/assets/immutable/*
  Cache-Control: public, max-age=31536000, immutable
`;
}

export function renderDemoHeaders(environment: DeploymentEnvironment): string {
  const peer = HOSTS[environment];
  const csp = [
    "default-src 'none'",
    "base-uri 'self'",
    "form-action 'none'",
    `frame-ancestors ${peer.landing}`,
    "script-src 'self' 'wasm-unsafe-eval'",
    "style-src 'self'",
    "style-src-elem 'self' 'unsafe-inline'",
    "style-src-attr 'none'",
    "font-src 'self' data:",
    "img-src 'self' data: blob:",
    "connect-src 'self'",
    "object-src 'none'",
    "media-src 'none'",
    "manifest-src 'self'",
    "worker-src 'none'",
    "upgrade-insecure-requests",
  ].join("; ");
  return `/*
  Content-Security-Policy: ${csp}
  Permissions-Policy: accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
  Referrer-Policy: no-referrer
  X-Content-Type-Options: nosniff
  Cross-Origin-Resource-Policy: same-origin
  ${NOINDEX}

${entryCacheRules(["/", "/index.html", "/flutter.js", "/flutter_bootstrap.js", "/main.dart.js", "/manifest.json", "/version.json", "/asset-manifest.json"])}
`;
}

const HASH_MANIFEST = "asset-manifest.json";
const EXCLUDED_BUILD_MARKERS = new Set([".last_build_id"]);
const TEXT_EXTENSIONS = new Set([".css", ".html", ".js", ".json", ".webmanifest"]);
const FORBIDDEN_PROVIDER_PATTERNS = [
  /auth0/i,
  /api(?:-beta)?\.just-build-this\.app/i,
  /\/v1\/session\/bootstrap/i,
  /@neondatabase\/serverless/i,
  /drizzle-orm/i,
  /postgres(?:ql)?:\/\//i,
  /flutter_secure_storage/i,
  /path_provider/i,
];
const UTF8 = new TextDecoder();

export type AssetManifest = {
  algorithm: "sha256";
  fileCount: number;
  totalBytes: number;
  files: Array<{ path: string; bytes: number; sha256: string }>;
};

type AssembleOptions = {
  source: string;
  destination: string;
};

function posixPath(path: string): string {
  return path.split(sep).join("/");
}

async function walk(root: string, directory = root): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
    const absolute = join(directory, entry.name);
    const metadata = await lstat(absolute);
    if (metadata.isSymbolicLink()) throw new Error(`Asset source cannot contain symlinks: ${entry.name}`);
    if (metadata.isDirectory()) files.push(...(await walk(root, absolute)));
    else if (metadata.isFile()) files.push(posixPath(relative(root, absolute)));
  }
  return files.sort();
}

function extension(path: string): string {
  const dot = path.lastIndexOf(".");
  return dot < 0 ? "" : path.slice(dot).toLowerCase();
}

function referencedAssets(path: string, contents: string): string[] {
  const references: string[] = [];
  if (path.endsWith(".html")) {
    for (const match of contents.matchAll(/(?:src|poster)\s*=\s*["']([^"']+)["']/gi)) {
      if (match[1] !== undefined) references.push(match[1]);
    }
    for (const tag of contents.matchAll(/<link\b[^>]*>/gi)) {
      const rel = tag[0].match(/\brel\s*=\s*["']([^"']+)["']/i)?.[1]?.toLowerCase().split(/\s+/) ?? [];
      if (!rel.some((value) => ["stylesheet", "icon", "manifest", "preload", "modulepreload"].includes(value))) continue;
      const href = tag[0].match(/\bhref\s*=\s*["']([^"']+)["']/i)?.[1];
      if (href !== undefined) references.push(href);
    }
  }
  if (path.endsWith(".css")) {
    for (const match of contents.matchAll(/url\(\s*["']?([^"')]+)["']?\s*\)/gi)) {
      if (match[1] !== undefined) references.push(match[1]);
    }
  }
  if (path.endsWith("manifest.json") || path.endsWith(".webmanifest")) {
    try {
      const manifest = JSON.parse(contents) as { icons?: Array<{ src?: unknown }> };
      for (const icon of manifest.icons ?? []) {
        if (typeof icon.src === "string") references.push(icon.src);
      }
    } catch {
      throw new Error(`Invalid JSON asset manifest: ${path}`);
    }
  }
  if (path === "flutter_bootstrap.js") {
    const encodedConfig = contents.match(/_flutter\.buildConfig\s*=\s*(\{[\s\S]*?\});/)?.[1];
    if (encodedConfig === undefined) throw new Error("Flutter bootstrap is missing its build configuration.");
    const buildConfig = JSON.parse(encodedConfig) as {
      builds?: Array<{ mainJsPath?: unknown }>;
      useLocalCanvasKit?: unknown;
      wasmHashes?: Record<string, unknown>;
    };
    if (buildConfig.useLocalCanvasKit !== true) {
      throw new Error("Remote Flutter runtime assets are forbidden; useLocalCanvasKit must be true.");
    }
    for (const build of buildConfig.builds ?? []) {
      if (typeof build.mainJsPath === "string") references.push(build.mainJsPath);
    }
    for (const wasm of Object.keys(buildConfig.wasmHashes ?? {})) {
      const localWasm = `canvaskit/${wasm}`;
      references.push(localWasm, localWasm.replace(/\.wasm$/, ".js"));
    }
  }
  return references;
}

function normalizeReference(reference: string): string | null {
  if (/^(?:https?:|\/\/)/i.test(reference)) {
    throw new Error(`Remote runtime asset reference is forbidden: ${reference}`);
  }
  if (/^(?:data:|blob:|#)/i.test(reference)) return null;
  if (/^[a-z]+:/i.test(reference)) return null;
  const withoutQuery = reference.split(/[?#]/, 1)[0];
  if (withoutQuery === undefined || withoutQuery === "" || withoutQuery === ".") return null;
  return decodeURIComponent(withoutQuery).replace(/^\//, "");
}

function referenceExists(deployable: ReadonlySet<string>, reference: string): boolean {
  const normalized = normalizeReference(reference);
  if (normalized === null) return true;
  if (normalized === ".." || normalized.startsWith("../") || normalized.includes("/../")) return false;
  return deployable.has(normalized) || deployable.has(`${normalized.replace(/\/$/, "")}/index.html`);
}

function validateProviderBoundary(path: string, contents: Uint8Array): void {
  if (!TEXT_EXTENSIONS.has(extension(path))) return;
  const text = UTF8.decode(contents);
  for (const pattern of FORBIDDEN_PROVIDER_PATTERNS) {
    if (pattern.test(text)) throw new Error(`provider boundary violation in ${path}.`);
  }
}

async function validateManifest(destination: string, manifest: AssetManifest): Promise<void> {
  if (manifest.fileCount !== manifest.files.length) throw new Error("Asset manifest count mismatch.");
  let totalBytes = 0;
  for (const file of manifest.files) {
    const contents = await readFile(join(destination, file.path));
    const digest = createHash("sha256").update(contents).digest("hex");
    if (contents.byteLength !== file.bytes || digest !== file.sha256) {
      throw new Error(`Asset manifest hash mismatch: ${file.path}`);
    }
    totalBytes += contents.byteLength;
  }
  if (totalBytes !== manifest.totalBytes) throw new Error("Asset manifest byte total mismatch.");
}

export async function assembleAssets(options: AssembleOptions): Promise<AssetManifest> {
  const source = resolve(options.source);
  const destination = resolve(options.destination);
  if (source === destination || source.startsWith(`${destination}${sep}`)) {
    throw new Error("Asset source and destination must be separate directories.");
  }

  const sourceFiles = await walk(source);
  const deployable: Array<{ path: string; contents: Uint8Array }> = [];
  for (const path of sourceFiles) {
    if (EXCLUDED_BUILD_MARKERS.has(path)) continue;
    if (path.endsWith(".map")) throw new Error(`source map output is forbidden: ${path}`);
    if (path.endsWith(".symbols")) continue;
    const contents = await readFile(join(source, path));
    if (path === "flutter_service_worker.js") {
      if (contents.byteLength === 0) continue;
      throw new Error("service worker output is forbidden.");
    }
    if (contents.byteLength > MAX_ASSET_BYTES) {
      throw new Error(`Asset exceeds Cloudflare's 25 MiB per-file limit: ${path}`);
    }
    validateProviderBoundary(path, contents);
    deployable.push({ path, contents });
  }

  const deployablePaths = new Set(deployable.map((asset) => asset.path));
  for (const file of deployable) {
    if (!TEXT_EXTENSIONS.has(extension(file.path))) continue;
    for (const reference of referencedAssets(file.path, UTF8.decode(file.contents))) {
      if (!referenceExists(deployablePaths, reference)) {
        throw new Error(`Missing referenced asset from ${file.path}: ${reference}`);
      }
    }
  }

  await rm(destination, { recursive: true, force: true });
  await mkdir(destination, { recursive: true });
  const files: AssetManifest["files"] = [];
  for (const file of deployable) {
    const target = join(destination, file.path);
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, file.contents);
    files.push({
      path: file.path,
      bytes: file.contents.byteLength,
      sha256: createHash("sha256").update(file.contents).digest("hex"),
    });
  }
  files.sort((left, right) => left.path.localeCompare(right.path));
  const manifest: AssetManifest = {
    algorithm: "sha256",
    fileCount: files.length,
    totalBytes: files.reduce((sum, file) => sum + file.bytes, 0),
    files,
  };
  await writeFile(join(destination, HASH_MANIFEST), `${JSON.stringify(manifest, null, 2)}\n`);
  await validateManifest(destination, manifest);
  return manifest;
}

const LANDING_ASSETS = [
  {
    source: "../ritual-investing-app/assets/fonts/Inter-Variable.ttf",
    output: "inter.29160a80ff49.ttf",
    hashPrefix: "29160a80ff49",
  },
  {
    source: "../ritual-investing-app/assets/fonts/LibreBaskerville-Variable.ttf",
    output: "libre-baskerville.05a954219613.ttf",
    hashPrefix: "05a954219613",
  },
  {
    source: "../ritual-investing-app/assets/images/the-compass.png",
    output: "the-compass.2da5b20ad40a.png",
    hashPrefix: "2da5b20ad40a",
  },
] as const;

async function addLandingIdentityAssets(packageRoot: string, stage: string): Promise<void> {
  const destination = join(stage, "assets/immutable");
  await mkdir(destination, { recursive: true });
  for (const asset of LANDING_ASSETS) {
    const source = resolve(packageRoot, asset.source);
    const contents = await readFile(source);
    const digest = createHash("sha256").update(contents).digest("hex");
    if (!digest.startsWith(asset.hashPrefix)) {
      throw new Error(`Fingerprint drift for landing identity asset: ${asset.source}`);
    }
    await copyFile(source, join(destination, asset.output));
  }
}

async function prepareLandingStage(
  packageRoot: string,
  stage: string,
  environment: DeploymentEnvironment,
): Promise<void> {
  await cp(resolve(packageRoot, "public"), stage, { recursive: true });
  await addLandingIdentityAssets(packageRoot, stage);
  const publicSiteKey = process.env[
    environment === "production" ? "TURNSTILE_SITE_KEY_PRODUCTION" : "TURNSTILE_SITE_KEY_BETA"
  ]?.trim();
  if (publicSiteKey !== undefined && publicSiteKey !== "") {
    const indexPath = join(stage, "index.html");
    await writeFile(indexPath, injectTurnstileSiteKey(await readFile(indexPath, "utf8"), publicSiteKey));
  }
  await writeFile(join(stage, "_headers"), renderLandingHeaders(environment));
  if (environment === "beta") {
    for (const relativePath of ["index.html", "privacy/waitlist/index.html"]) {
      const path = join(stage, relativePath);
      const production = await readFile(path, "utf8");
      const beta = production
        .replaceAll('content="index,follow"', 'content="noindex,nofollow"')
        .replaceAll('data-demo-environment="production"', 'data-demo-environment="beta"')
        .replaceAll("https://demo.just-build-this.app", "https://demo-beta.just-build-this.app");
      await writeFile(path, beta);
    }
    await writeFile(join(stage, "robots.txt"), "User-agent: *\nDisallow: /\n");
  }
}

async function prepareDemoStage(
  demoSource: string,
  stage: string,
  environment: DeploymentEnvironment,
): Promise<void> {
  await cp(demoSource, stage, { recursive: true });
  await writeFile(join(stage, "_headers"), renderDemoHeaders(environment));
  await writeFile(join(stage, "robots.txt"), "User-agent: *\nDisallow: /\n");
}

export async function buildDeploymentAssets(): Promise<void> {
  const packageRoot = resolve(import.meta.dirname, "..");
  const demoSource = resolve(packageRoot, "../ritual-investing-demo/build/web");
  const stagingRoot = await mkdtemp(join(tmpdir(), "ritual-site-assets-"));
  try {
    const manifests: Array<{ surface: string; manifest: AssetManifest }> = [];
    for (const environment of ["production", "beta"] as const) {
      const landingStage = join(stagingRoot, `landing-${environment}`);
      await prepareLandingStage(packageRoot, landingStage, environment);
      manifests.push({
        surface: environment === "production" ? "landing" : "landing-beta",
        manifest: await assembleAssets({
          source: landingStage,
          destination: resolve(packageRoot, environment === "production" ? "dist/landing" : "dist/landing-beta"),
        }),
      });

      const demoStage = join(stagingRoot, `demo-${environment}`);
      await prepareDemoStage(demoSource, demoStage, environment);
      manifests.push({
        surface: environment === "production" ? "demo" : "demo-beta",
        manifest: await assembleAssets({
          source: demoStage,
          destination: resolve(packageRoot, environment === "production" ? "dist/demo" : "dist/demo-beta"),
        }),
      });
    }
    process.stdout.write(manifests.map(({ surface, manifest }) =>
      `${surface}: ${manifest.fileCount} files (${manifest.totalBytes} bytes)`,
    ).join("\n") + "\n");
  } finally {
    await rm(stagingRoot, { recursive: true, force: true });
  }
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await buildDeploymentAssets();
}
