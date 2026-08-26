import { createHash } from "node:crypto";
import {
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

async function buildDeploymentAssets(): Promise<void> {
  const packageRoot = resolve(import.meta.dirname, "..");
  const demoSource = resolve(packageRoot, "../ritual-investing-demo/build/web");
  const demoManifest = await assembleAssets({ source: demoSource, destination: resolve(packageRoot, "dist/demo") });

  const scaffold = await mkdtemp(join(tmpdir(), "ritual-landing-scaffold-"));
  try {
    await writeFile(
      join(scaffold, "index.html"),
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="robots" content="noindex"></head><body><main><h1>Ritual Investing</h1><p>Landing page scaffold; public content is assembled in U4.</p></main></body></html>\n',
    );
    const landingManifest = await assembleAssets({ source: scaffold, destination: resolve(packageRoot, "dist/landing") });
    process.stdout.write(
      `Assembled ${demoManifest.fileCount} demo files (${demoManifest.totalBytes} bytes) and ${landingManifest.fileCount} landing scaffold file.\n`,
    );
  } finally {
    await rm(scaffold, { recursive: true, force: true });
  }
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await buildDeploymentAssets();
}
