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

type DeploymentEnvironment = "dev" | "staging" | "prod";
type DeploymentSurface = "landing" | "demo" | "member";

export type DeploymentWaitlistConfiguration = {
  functionUrl: string;
  turnstileSiteKey: string;
};

export type DeploymentWaitlistConfigurations = Record<
  "staging" | "prod",
  DeploymentWaitlistConfiguration | null
>;

export const DEPLOYMENT_TARGETS = [
  {
    environment: "staging",
    landingDirectory: "dist/landing-staging",
    demoDirectory: "dist/demo-staging",
  },
  {
    environment: "prod",
    landingDirectory: "dist/landing-prod",
    demoDirectory: "dist/demo-prod",
  },
] as const;

export type MemberStagingAssemblyInputs = {
  projectRef: string;
  publishableKeySha256: string;
  supabaseOrigin: string;
};

const HOSTS = {
  prod: {
    landing: "https://just-build-this.app",
    demo: "https://demo.just-build-this.app",
  },
  staging: {
    landing: "https://staging.just-build-this.app",
    demo: "https://demo-staging.just-build-this.app",
  },
} as const;

const NOINDEX = "X-Robots-Tag: noindex, nofollow, noarchive";
const TURNSTILE_SITE_KEY_ATTRIBUTE = 'data-turnstile-site-key=""';
const WAITLIST_CONFIGURATION_SEAM =
  'action="" method="post" data-waitlist-form data-waitlist-enabled="false"';

export function injectTurnstileSiteKey(html: string, siteKey: string): string {
  if (!/^[A-Za-z0-9_-]{20,128}$/.test(siteKey)) {
    throw new Error("The Turnstile site key has an invalid public-key shape.");
  }
  if (html.split(TURNSTILE_SITE_KEY_ATTRIBUTE).length !== 2) {
    throw new Error("The landing must contain exactly one empty Turnstile site-key seam.");
  }
  return html.replace(TURNSTILE_SITE_KEY_ATTRIBUTE, `data-turnstile-site-key="${siteKey}"`);
}

export function resolveTurnstileSiteKey(
  environment: DeploymentEnvironment,
  variables: Record<string, string | undefined>,
  required: boolean,
): string | undefined {
  if (environment === "dev") {
    throw new Error("Dev assets are local-only and cannot be assembled for deployment.");
  }
  const variable = environment === "prod"
    ? "TURNSTILE_SITE_KEY_PROD"
    : "TURNSTILE_SITE_KEY_STAGING";
  const siteKey = variables[variable]?.trim();
  if (siteKey === undefined || siteKey === "") {
    if (required) throw new Error(`${environment} Turnstile site key is required for release assembly.`);
    return undefined;
  }
  if (!/^[A-Za-z0-9_-]{20,128}$/.test(siteKey)) {
    throw new Error(`${environment} Turnstile site key has an invalid public-key shape.`);
  }
  return siteKey;
}

export function resolveWaitlistFunctionUrl(
  environment: DeploymentEnvironment,
  variables: Record<string, string | undefined>,
  required: boolean,
): string | undefined {
  if (environment === "dev") {
    throw new Error("Dev assets are local-only and cannot be assembled for deployment.");
  }
  const variable = environment === "prod"
    ? "WAITLIST_FUNCTION_URL_PROD"
    : "WAITLIST_FUNCTION_URL_STAGING";
  const value = variables[variable]?.trim();
  if (value === undefined || value === "") {
    if (required) {
      throw new Error(
        `${environment} Supabase waitlist function URL is required for release assembly.`,
      );
    }
    return undefined;
  }
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${environment} Supabase waitlist function URL is invalid.`);
  }
  if (
    parsed.protocol !== "https:" ||
    !/^[a-z0-9-]+\.supabase\.co$/i.test(parsed.hostname) ||
    parsed.port !== "" ||
    parsed.username !== "" ||
    parsed.password !== "" ||
    parsed.pathname !== "/functions/v1/waitlist" ||
    parsed.search !== "" ||
    parsed.hash !== "" ||
    parsed.href !== value
  ) {
    throw new Error(
      `${environment} Supabase waitlist function URL must be an exact HTTPS /functions/v1/waitlist endpoint.`,
    );
  }
  return value;
}

export function injectWaitlistConfiguration(
  html: string,
  functionUrl: string,
): string {
  if (html.split(WAITLIST_CONFIGURATION_SEAM).length !== 2) {
    throw new Error("The landing must contain exactly one disabled waitlist seam.");
  }
  resolveWaitlistFunctionUrl("prod", {
    WAITLIST_FUNCTION_URL_PROD: functionUrl,
  }, true);
  return html.replace(
    WAITLIST_CONFIGURATION_SEAM,
    `action="${functionUrl}" method="post" data-waitlist-form data-waitlist-enabled="true"`,
  );
}

function entryCacheRules(paths: readonly string[]): string {
  return paths.map((path) => `${path}\n  Cache-Control: no-cache, no-store, must-revalidate`).join("\n\n");
}

export function renderLandingHeaders(
  environment: DeploymentEnvironment,
  waitlistFunctionUrl?: string,
): string {
  if (environment === "dev") {
    throw new Error("Dev assets are local-only and have no hosted response policy.");
  }
  const peer = HOSTS[environment];
  const waitlistOrigin = waitlistFunctionUrl === undefined
    ? undefined
    : new URL(waitlistFunctionUrl).origin;
  const csp = [
    "default-src 'none'",
    "base-uri 'none'",
    waitlistOrigin === undefined
      ? "form-action 'none'"
      : `form-action ${waitlistOrigin}`,
    "frame-ancestors 'none'",
    `frame-src ${peer.demo} https://challenges.cloudflare.com`,
    "script-src 'self' https://challenges.cloudflare.com",
    "style-src 'self'",
    "font-src 'self'",
    "img-src 'self'",
    `connect-src 'self' https://challenges.cloudflare.com${
      waitlistOrigin === undefined ? "" : ` ${waitlistOrigin}`
    }`,
    "object-src 'none'",
    "media-src 'none'",
    "manifest-src 'none'",
    "worker-src 'none'",
    "upgrade-insecure-requests",
  ].join("; ");
  const indexPolicy = environment === "staging" ? `\n  ${NOINDEX}` : "";
  return `/*
  Content-Security-Policy: ${csp}
  Permissions-Policy: accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
  Referrer-Policy: strict-origin-when-cross-origin
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Resource-Policy: same-origin${indexPolicy}

${entryCacheRules(["/", "/index.html", "/404.html", "/privacy/waitlist", "/privacy/waitlist/", "/privacy/waitlist/index.html", "/landing.js", "/styles.css", "/robots.txt", "/sitemap.xml"])}

/assets/immutable/*
  Cache-Control: public, max-age=31536000, immutable
`;
}

export function renderDemoHeaders(environment: DeploymentEnvironment): string {
  if (environment === "dev") {
    throw new Error("Dev assets are local-only and have no hosted response policy.");
  }
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

${entryCacheRules(["/", "/index.html", "/404.html", "/flutter.js", "/flutter_bootstrap.js", "/main.dart.js", "/manifest.json", "/version.json", "/asset-manifest.json"])}
`;
}

export function resolveMemberStagingAssemblyInputs(
  variables: Record<string, string | undefined>,
): MemberStagingAssemblyInputs {
  const projectRef = variables.MEMBER_STAGING_SUPABASE_PROJECT_REF?.trim() ?? "";
  const supabaseOrigin = variables.MEMBER_STAGING_SUPABASE_ORIGIN?.trim() ?? "";
  const publishableKeySha256 =
    variables.MEMBER_STAGING_SUPABASE_PUBLISHABLE_KEY_SHA256?.trim().toLowerCase() ?? "";
  if (!/^[a-z0-9]{20}$/.test(projectRef)) {
    throw new Error("The staging Supabase project ref is required.");
  }
  if (supabaseOrigin !== `https://${projectRef}.supabase.co`) {
    throw new Error("The member staging Supabase origin must exactly match its project ref.");
  }
  if (!/^[a-f0-9]{64}$/.test(publishableKeySha256)) {
    throw new Error("The member staging publishable-key SHA-256 fingerprint is required.");
  }
  return { projectRef, publishableKeySha256, supabaseOrigin };
}

export function renderMemberHeaders(
  supabaseOrigin: string,
  immutablePaths: readonly string[] = [],
): string {
  const csp = [
    "default-src 'none'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
    "script-src 'self' 'wasm-unsafe-eval'",
    "style-src 'self'",
    "font-src 'self'",
    "img-src 'self' blob:",
    `connect-src 'self' ${supabaseOrigin}`,
    "object-src 'none'",
    "media-src 'none'",
    "manifest-src 'self'",
    "worker-src 'none'",
    "upgrade-insecure-requests",
  ].join("; ");
  const immutable = immutablePaths
    .map((path) => `/${path}\n  Cache-Control: public, max-age=31536000, immutable`)
    .join("\n\n");
  const revalidating = [
    "/", "/index.html", "/flutter.js", "/flutter_bootstrap.js", "/main.dart.js",
    "/manifest.json", "/version.json", "/asset-manifest.json", "/canvaskit/*",
    "/assets/*",
  ];
  return `/*
  Content-Security-Policy: ${csp}
  Permissions-Policy: accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()
  Referrer-Policy: no-referrer
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Resource-Policy: same-origin
  ${NOINDEX}

${entryCacheRules(revalidating)}

/mobile/argus-auth/callback
  Cache-Control: no-store
  Referrer-Policy: no-referrer

/auth/recovery
  Cache-Control: no-store
  Referrer-Policy: no-referrer${immutable === "" ? "" : `\n\n${immutable}`}
`;
}

const HASH_MANIFEST = "asset-manifest.json";
const EXCLUDED_BUILD_MARKERS = new Set([".last_build_id"]);
const TEXT_EXTENSIONS = new Set([".css", ".html", ".js", ".json", ".webmanifest"]);
const FORBIDDEN_PROVIDER_PATTERNS = [
  /auth0/i,
  /api(?:-beta)?\.just-build-this\.app/i,
  /@neondatabase\/serverless/i,
  /drizzle-orm/i,
  /postgres(?:ql)?:\/\//i,
  /flutter_secure_storage/i,
  /path_provider/i,
  /sb_secret_[A-Za-z0-9_-]{20,}/i,
  /service[_-]?role/i,
  /SUPABASE_(?:SECRET|SERVICE)/i,
  /TURNSTILE_SECRET/i,
  /WAITLIST_SOURCE_HMAC_KEY/i,
  /passport\.webull\.com/i,
  /oauth-open-api[^\s"']*webull\.com/i,
  /createWebullClient/i,
  /WebullTokenVault/i,
];
const NON_MEMBER_FORBIDDEN_PROVIDER_PATTERNS = [/\/v1\/session\/bootstrap/i];
const DEMO_ONLY_FORBIDDEN_PROVIDER_PATTERNS = [
  /supabase/i,
  /\/functions\/v1\//i,
  /\/api\/waitlist/i,
  /challenges\.cloudflare\.com/i,
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
  surface?: DeploymentSurface;
  memberStaging?: MemberStagingAssemblyInputs;
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

function validateProviderBoundary(
  path: string,
  contents: Uint8Array,
  surface: DeploymentSurface,
): void {
  if (!TEXT_EXTENSIONS.has(extension(path))) return;
  const text = UTF8.decode(contents);
  for (const pattern of FORBIDDEN_PROVIDER_PATTERNS) {
    if (pattern.test(text)) throw new Error(`provider boundary violation in ${path}.`);
  }
  if (surface !== "member") {
    for (const pattern of NON_MEMBER_FORBIDDEN_PROVIDER_PATTERNS) {
      if (pattern.test(text)) throw new Error(`provider boundary violation in ${path}.`);
    }
  }
  if (surface === "demo") {
    for (const pattern of DEMO_ONLY_FORBIDDEN_PROVIDER_PATTERNS) {
      if (pattern.test(text)) {
        throw new Error(`demo provider boundary violation in ${path}.`);
      }
    }
  }
}

function validateMemberStagingBoundary(
  assets: ReadonlyArray<{ path: string; contents: Uint8Array }>,
  inputs: MemberStagingAssemblyInputs,
): void {
  const text = assets
    .filter((asset) => TEXT_EXTENSIONS.has(extension(asset.path)))
    .map((asset) => UTF8.decode(asset.contents))
    .join("\n");
  const apiUrl = `${inputs.supabaseOrigin}/functions/v1/api`;
  if (!text.includes(inputs.supabaseOrigin) || !text.includes(apiUrl)) {
    throw new Error("The member artifact is missing its exact staging Supabase origin or Edge API URL.");
  }
  const origins = new Set(
    [...text.matchAll(/https:\/\/[a-z0-9-]+\.supabase\.co/gi)].map((match) => match[0]),
  );
  if (origins.size !== 1 || !origins.has(inputs.supabaseOrigin)) {
    throw new Error("The member artifact contains an unapproved Supabase origin.");
  }
  if (/https:\/\/[a-z0-9-]+\.supabase\.co\/(?:rest|graphql|realtime|storage)\/v1/gi.test(text)) {
    throw new Error("The member artifact contains a direct Supabase application-data endpoint.");
  }
  const keys = new Set(text.match(/sb_publishable_[A-Za-z0-9_-]+/g) ?? []);
  if (keys.size !== 1) {
    throw new Error("The member artifact must contain exactly one publishable key.");
  }
  const key = [...keys][0];
  if (key === undefined || createHash("sha256").update(key).digest("hex") !== inputs.publishableKeySha256) {
    throw new Error("The member artifact publishable-key fingerprint does not match.");
  }
  if (/eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/.test(text)) {
    throw new Error("Legacy JWT-shaped keys are forbidden in the member artifact.");
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
  const surface = options.surface ?? "demo";
  if (surface === "member" && options.memberStaging === undefined) {
    throw new Error("Member staging assembly requires exact staging Supabase inputs.");
  }
  if (source === destination || source.startsWith(`${destination}${sep}`)) {
    throw new Error("Asset source and destination must be separate directories.");
  }

  const sourceFiles = await walk(source);
  const deployable: Array<{ path: string; contents: Uint8Array }> = [];
  for (const path of sourceFiles) {
    if (EXCLUDED_BUILD_MARKERS.has(path)) continue;
    if (
      path === "_worker.js" || path === "_routes.json" || path === "_redirects" ||
      path === "functions" || path.startsWith("functions/")
    ) {
      throw new Error(`Cloudflare compute artifact is forbidden: ${path}`);
    }
    if (path.endsWith(".map")) throw new Error(`source map output is forbidden: ${path}`);
    if (path.endsWith(".symbols")) continue;
    const contents = await readFile(join(source, path));
    if (/(?:^|\/)(?:flutter_service_worker|service[-_]?worker|sw)\.js$/i.test(path)) {
      if (path !== "flutter_service_worker.js") {
        throw new Error(`service worker output is forbidden: ${path}`);
      }
      if (contents.byteLength === 0) continue;
      throw new Error("service worker output is forbidden.");
    }
    if (contents.byteLength > MAX_ASSET_BYTES) {
      throw new Error(`Asset exceeds Cloudflare's 25 MiB per-file limit: ${path}`);
    }
    validateProviderBoundary(path, contents, surface);
    deployable.push({ path, contents });
  }

  if (surface === "member") validateMemberStagingBoundary(deployable, options.memberStaging!);

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
  reviewedConfiguration?: DeploymentWaitlistConfiguration | null,
): Promise<void> {
  await cp(resolve(packageRoot, "public"), stage, { recursive: true });
  await addLandingIdentityAssets(packageRoot, stage);
  const publicSiteKey = reviewedConfiguration === null
    ? undefined
    : resolveTurnstileSiteKey(
      environment,
      reviewedConfiguration === undefined
        ? process.env
        : { [`TURNSTILE_SITE_KEY_${environment.toUpperCase()}`]: reviewedConfiguration.turnstileSiteKey },
      reviewedConfiguration !== undefined || process.env.REQUIRE_WAITLIST_CONFIGURATION === "true",
    );
  const waitlistFunctionUrl = reviewedConfiguration === null
    ? undefined
    : resolveWaitlistFunctionUrl(
      environment,
      reviewedConfiguration === undefined
        ? process.env
        : { [`WAITLIST_FUNCTION_URL_${environment.toUpperCase()}`]: reviewedConfiguration.functionUrl },
      reviewedConfiguration !== undefined || process.env.REQUIRE_WAITLIST_CONFIGURATION === "true",
    );
  if ((publicSiteKey === undefined) !== (waitlistFunctionUrl === undefined)) {
    throw new Error(
      `${environment} waitlist activation requires both the public Turnstile key and function URL.`,
    );
  }
  if (publicSiteKey !== undefined && waitlistFunctionUrl !== undefined) {
    const indexPath = join(stage, "index.html");
    const html = injectTurnstileSiteKey(
      await readFile(indexPath, "utf8"),
      publicSiteKey,
    );
    await writeFile(
      indexPath,
      injectWaitlistConfiguration(html, waitlistFunctionUrl),
    );
  }
  await writeFile(
    join(stage, "_headers"),
    renderLandingHeaders(environment, waitlistFunctionUrl),
  );
  if (environment === "staging") {
    for (const relativePath of ["index.html", "privacy/waitlist/index.html"]) {
      const path = join(stage, relativePath);
      const prod = await readFile(path, "utf8");
      const staging = prod
        .replaceAll('content="index,follow"', 'content="noindex,nofollow"')
        .replaceAll('data-demo-environment="prod"', 'data-demo-environment="staging"')
        .replaceAll("https://demo.just-build-this.app", "https://demo-staging.just-build-this.app");
      await writeFile(path, staging);
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

async function prepareMemberStage(
  memberSource: string,
  stage: string,
  inputs: MemberStagingAssemblyInputs,
): Promise<void> {
  await cp(memberSource, stage, { recursive: true });
  const paths = await walk(stage);
  if (paths.includes("_headers")) {
    throw new Error("The Flutter member build cannot supply its own _headers file.");
  }
  const immutablePaths: string[] = [];
  for (const path of paths) {
    const claimedHash = path.match(/(?:^|\/)[^/]*[.-]([a-f0-9]{8,64})\.[^/]+$/i)?.[1];
    if (claimedHash === undefined) continue;
    const digest = createHash("sha256").update(await readFile(join(stage, path))).digest("hex");
    if (digest.startsWith(claimedHash.toLowerCase())) immutablePaths.push(path);
  }
  await writeFile(join(stage, "_headers"), renderMemberHeaders(inputs.supabaseOrigin, immutablePaths));
  await writeFile(join(stage, "robots.txt"), "User-agent: *\nDisallow: /\n");
}

export async function buildMemberStagingAssets(
  inputs: MemberStagingAssemblyInputs,
): Promise<AssetManifest> {
  const packageRoot = resolve(import.meta.dirname, "..");
  const memberSource = resolve(packageRoot, "../ritual-investing-app/build/web");
  const stage = await mkdtemp(join(tmpdir(), "ritual-member-assets-"));
  try {
    await prepareMemberStage(memberSource, stage, inputs);
    return await assembleAssets({
      source: stage,
      destination: resolve(packageRoot, "dist/member-staging"),
      surface: "member",
      memberStaging: inputs,
    });
  } finally {
    await rm(stage, { recursive: true, force: true });
  }
}

export async function buildDeploymentAssets(
  reviewedConfigurations?: DeploymentWaitlistConfigurations,
): Promise<void> {
  const packageRoot = resolve(import.meta.dirname, "..");
  const demoSource = resolve(packageRoot, "../ritual-investing-demo/build/web");
  const stagingRoot = await mkdtemp(join(tmpdir(), "ritual-site-assets-"));
  try {
    const manifests: Array<{ surface: string; manifest: AssetManifest }> = [];
    for (const target of DEPLOYMENT_TARGETS) {
      const { environment } = target;
      const landingStage = join(stagingRoot, `landing-${environment}`);
      await prepareLandingStage(
        packageRoot,
        landingStage,
        environment,
        reviewedConfigurations?.[environment],
      );
      manifests.push({
        surface: `landing-${environment}`,
        manifest: await assembleAssets({
          source: landingStage,
          destination: resolve(packageRoot, target.landingDirectory),
          surface: "landing",
        }),
      });

      const demoStage = join(stagingRoot, `demo-${environment}`);
      await prepareDemoStage(demoSource, demoStage, environment);
      manifests.push({
        surface: `demo-${environment}`,
        manifest: await assembleAssets({
          source: demoStage,
          destination: resolve(packageRoot, target.demoDirectory),
          surface: "demo",
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
  if (process.argv[2] === "member-staging") {
    const manifest = await buildMemberStagingAssets(resolveMemberStagingAssemblyInputs(process.env));
    process.stdout.write(`member-staging: ${manifest.fileCount} files (${manifest.totalBytes} bytes)\n`);
  } else {
    await buildDeploymentAssets();
  }
}
