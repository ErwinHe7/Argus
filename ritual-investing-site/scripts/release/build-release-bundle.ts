import { createHash } from "node:crypto";
import {
  chmod,
  lstat,
  mkdir,
  readFile,
  readdir,
  rm,
  utimes,
  writeFile,
} from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

import {
  buildDeploymentAssets,
  type DeploymentWaitlistConfigurations,
} from "../build-assets.ts";
import {
  assertReleaseContentsSafe,
  calculateBackendSourceSha256,
  calculateProbeManifestSha256,
  isExcludedReleaseSource,
  isSecretShapedReleasePath,
  parseReleaseManifest,
  parseReleaseProfile,
  type ReleaseControllerIdentity,
  type ReleaseDigestEntry,
  type ReleaseEnvironment,
  type ReleaseFileEntry,
  type ReleaseManifest,
  type ReleaseProfile,
  type ReleaseSubjectIdentity,
  type ReleaseSurface,
} from "./verify-release-bundle.ts";

export type ReleaseToolVersions = ReleaseManifest["tools"];
export type ReleaseProvenance = {
  subject: ReleaseSubjectIdentity;
  controller: ReleaseControllerIdentity;
};

export type ReleaseBuildOptions = {
  repositoryRoot: string;
  packageRoot: string;
  outputDirectory: string;
  sourceDateEpoch: number;
  provenance: ReleaseProvenance;
  toolVersions: ReleaseToolVersions;
  buildAssets?: (configurations: DeploymentWaitlistConfigurations) => Promise<void>;
};

export type ReleaseBuildResult = {
  bundleDirectory: string;
  archivePath: string;
  archiveSha256: string;
  manifest: ReleaseManifest;
  manifestSha256: string;
};

const ENVIRONMENTS = ["staging", "prod"] as const;
const SURFACES = ["landing", "demo"] as const;
const STATIC_NOT_FOUND_PAGE = Buffer.from(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>Page not found</title>
</head>
<body>
  <main>
    <h1>Page not found</h1>
    <p>The requested page does not exist.</p>
  </main>
</body>
</html>
`);
const INVENTORY_DOCUMENTS = [
  "member-data-inventory.md",
  "supabase-boundary-manifest-v1.txt",
  "supabase-migration-inventory-v1.txt",
] as const;
const SNAPSHOT_LAYOUT = [
  {
    name: "terraform",
    source: "infra/terraform/ritual-investing",
    destination: "snapshots/infra/terraform/ritual-investing",
  },
  {
    name: "supabase-migrations",
    source: "supabase/migrations",
    destination: "snapshots/supabase/migrations",
  },
  {
    name: "supabase-functions",
    source: "supabase/functions",
    destination: "snapshots/supabase/functions",
  },
] as const;

function posixPath(value: string): string {
  return value.split(sep).join("/");
}

async function walk(root: string, directory = root): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const paths: string[] = [];
  for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
    const absolute = join(directory, entry.name);
    const metadata = await lstat(absolute);
    const path = posixPath(relative(root, absolute));
    if (metadata.isSymbolicLink()) throw new Error(`Release source cannot contain symlinks: ${path}`);
    if (metadata.isDirectory()) paths.push(...await walk(root, absolute));
    else if (metadata.isFile()) paths.push(path);
  }
  return paths.sort((left, right) => left.localeCompare(right));
}

async function writeStableFile(path: string, contents: Uint8Array, epoch: number): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, contents);
  await chmod(path, 0o644);
  await utimes(path, epoch, epoch);
}

async function copyReviewedTree(
  source: string,
  destination: string,
  bundleRoot: string,
  epoch: number,
): Promise<number> {
  const paths = await walk(source);
  let copied = 0;
  for (const path of paths) {
    if (isExcludedReleaseSource(path)) continue;
    if (isSecretShapedReleasePath(path)) {
      throw new Error(`Secret-shaped credential file is forbidden: ${path}`);
    }
    const contents = await readFile(join(source, path));
    assertReleaseContentsSafe(path, contents);
    await writeStableFile(join(bundleRoot, destination, path), contents, epoch);
    copied += 1;
  }
  if (copied === 0) throw new Error(`Release snapshot source is empty: ${source}`);
  return copied;
}

async function inventoryFiles(bundleRoot: string): Promise<ReleaseFileEntry[]> {
  const entries: ReleaseFileEntry[] = [];
  for (const path of await walk(bundleRoot)) {
    if (path === "release-manifest.json") continue;
    const contents = await readFile(join(bundleRoot, path));
    entries.push({
      path,
      bytes: contents.byteLength,
      sha256: createHash("sha256").update(contents).digest("hex"),
    });
  }
  return entries.sort((left, right) => left.path.localeCompare(right.path));
}

async function writeSurfaceProbeIdentity(
  surfaceRoot: string,
  revision: string,
  epoch: number,
): Promise<string> {
  const beforeIdentity = await inventoryFiles(surfaceRoot);
  const probeManifestSha256 = calculateProbeManifestSha256(beforeIdentity);
  const version = Buffer.from(`${JSON.stringify({
    schemaVersion: 1,
    revision,
    manifestSha256: probeManifestSha256,
  }, null, 2)}\n`);
  await writeStableFile(join(surfaceRoot, "version.json"), version, epoch);

  const files = (await inventoryFiles(surfaceRoot))
    .filter(({ path }) => path !== "asset-manifest.json")
    .sort((left, right) => left.path.localeCompare(right.path));
  const assetManifest = Buffer.from(`${JSON.stringify({
    algorithm: "sha256",
    fileCount: files.length,
    totalBytes: files.reduce((sum, file) => sum + file.bytes, 0),
    files,
  }, null, 2)}\n`);
  await writeStableFile(join(surfaceRoot, "asset-manifest.json"), assetManifest, epoch);
  return probeManifestSha256;
}

function digestEntries(entries: readonly ReleaseFileEntry[], root: string): ReleaseDigestEntry {
  const prefix = `${root}/`;
  const included = entries.filter(({ path }) => path === root || path.startsWith(prefix));
  const canonical = included.map(({ path, bytes, sha256 }) =>
    `${sha256} ${bytes} ${path === root ? "" : path.slice(prefix.length)}\n`,
  ).join("");
  return {
    root,
    fileCount: included.length,
    totalBytes: included.reduce((sum, entry) => sum + entry.bytes, 0),
    sha256: createHash("sha256").update(canonical).digest("hex"),
  };
}

function requiredProbeManifestDigest(digests: ReadonlyMap<string, string>, key: string): string {
  const digest = digests.get(key);
  if (digest === undefined) throw new Error(`Missing probe content manifest digest: ${key}`);
  return digest;
}

function tarString(header: Buffer, value: string, offset: number, length: number): void {
  const bytes = Buffer.from(value);
  if (bytes.length > length) throw new Error(`Ustar field is too long: ${value}`);
  bytes.copy(header, offset);
}

function tarOctal(header: Buffer, value: number, offset: number, length: number): void {
  const encoded = value.toString(8).padStart(length - 1, "0") + "\0";
  if (encoded.length > length) throw new Error(`Ustar numeric field is too large: ${value}`);
  tarString(header, encoded, offset, length);
}

function splitTarPath(path: string): { name: string; prefix: string } {
  if (Buffer.byteLength(path) <= 100) return { name: path, prefix: "" };
  for (let index = path.lastIndexOf("/"); index > 0; index = path.lastIndexOf("/", index - 1)) {
    const prefix = path.slice(0, index);
    const name = path.slice(index + 1);
    if (Buffer.byteLength(prefix) <= 155 && Buffer.byteLength(name) <= 100) return { name, prefix };
  }
  throw new Error(`Release path exceeds the ustar limit: ${path}`);
}

function tarHeader(path: string, size: number, epoch: number): Buffer {
  const header = Buffer.alloc(512);
  const split = splitTarPath(path);
  tarString(header, split.name, 0, 100);
  tarOctal(header, 0o644, 100, 8);
  tarOctal(header, 0, 108, 8);
  tarOctal(header, 0, 116, 8);
  tarOctal(header, size, 124, 12);
  tarOctal(header, epoch, 136, 12);
  header.fill(0x20, 148, 156);
  tarString(header, "0", 156, 1);
  tarString(header, "ustar\0", 257, 6);
  tarString(header, "00", 263, 2);
  if (split.prefix !== "") tarString(header, split.prefix, 345, 155);
  const checksum = header.reduce((sum, byte) => sum + byte, 0);
  tarString(header, checksum.toString(8).padStart(6, "0") + "\0 ", 148, 8);
  return header;
}

async function createDeterministicArchive(
  bundleDirectory: string,
  archivePath: string,
  epoch: number,
): Promise<Buffer> {
  const blocks: Buffer[] = [];
  for (const path of await walk(bundleDirectory)) {
    const contents = await readFile(join(bundleDirectory, path));
    blocks.push(tarHeader(`release-bundle/${path}`, contents.byteLength, epoch), contents);
    const padding = (512 - (contents.byteLength % 512)) % 512;
    if (padding > 0) blocks.push(Buffer.alloc(padding));
  }
  blocks.push(Buffer.alloc(1024));
  const archive = Buffer.concat(blocks);
  await writeStableFile(archivePath, archive, epoch);
  return archive;
}

function outputIsUnsafe(repositoryRoot: string, packageRoot: string, outputDirectory: string): boolean {
  const output = resolve(outputDirectory);
  return output === resolve(repositoryRoot) || output === resolve(packageRoot) ||
    resolve(repositoryRoot).startsWith(`${output}${sep}`) || resolve(packageRoot).startsWith(`${output}${sep}`);
}

async function loadProfile(packageRoot: string, environment: ReleaseEnvironment): Promise<{
  profile: ReleaseProfile;
  contents: Buffer;
}> {
  const contents = await readFile(join(packageRoot, `config/release/${environment}.json`));
  let parsed: unknown;
  try {
    parsed = JSON.parse(contents.toString("utf8"));
  } catch {
    throw new Error(`${environment} release profile must be valid JSON`);
  }
  return { profile: parseReleaseProfile(parsed, environment), contents };
}

export async function buildReleaseBundle(options: ReleaseBuildOptions): Promise<ReleaseBuildResult> {
  const repositoryRoot = resolve(options.repositoryRoot);
  const packageRoot = resolve(options.packageRoot);
  const outputDirectory = resolve(options.outputDirectory);
  if (!Number.isSafeInteger(options.sourceDateEpoch) || options.sourceDateEpoch < 0) {
    throw new Error("sourceDateEpoch must be a non-negative integer");
  }
  if (outputIsUnsafe(repositoryRoot, packageRoot, outputDirectory)) {
    throw new Error("Release output directory must not contain the repository or package root");
  }

  const loadedProfiles = await Promise.all(ENVIRONMENTS.map((environment) =>
    loadProfile(packageRoot, environment),
  ));
  const waitlistConfigurations = Object.fromEntries(loadedProfiles.map(({ profile }) => {
    const target = profile.targets.landing.backendDependency.target;
    return [
      profile.environment,
      target.status === "approved"
        ? { functionUrl: target.waitlistUrl, turnstileSiteKey: target.turnstileSiteKey }
        : null,
    ];
  })) as DeploymentWaitlistConfigurations;
  await (options.buildAssets ?? buildDeploymentAssets)(waitlistConfigurations);
  await rm(outputDirectory, { recursive: true, force: true });
  const bundleDirectory = join(outputDirectory, "release-bundle");
  await mkdir(bundleDirectory, { recursive: true });
  const probeManifestDigests = new Map<string, string>();

  for (let index = 0; index < ENVIRONMENTS.length; index += 1) {
    const environment = ENVIRONMENTS[index];
    const loaded = loadedProfiles[index];
    if (environment === undefined || loaded === undefined) throw new Error("Release profile inventory is incomplete");
    await writeStableFile(
      join(bundleDirectory, `profiles/${environment}/profile.json`),
      loaded.contents,
      options.sourceDateEpoch,
    );
    for (const surface of SURFACES) {
      await copyReviewedTree(
        join(packageRoot, `dist/${surface}-${environment}`),
        `trees/${environment}/${surface}`,
        bundleDirectory,
        options.sourceDateEpoch,
      );
      const surfaceRoot = join(bundleDirectory, `trees/${environment}/${surface}`);
      await writeStableFile(
        join(surfaceRoot, "404.html"),
        STATIC_NOT_FOUND_PAGE,
        options.sourceDateEpoch,
      );
      probeManifestDigests.set(
        `${environment}/${surface}`,
        await writeSurfaceProbeIdentity(surfaceRoot, options.provenance.subject.sha, options.sourceDateEpoch),
      );
    }
  }

  for (const snapshot of SNAPSHOT_LAYOUT) {
    await copyReviewedTree(
      join(repositoryRoot, snapshot.source),
      snapshot.destination,
      bundleDirectory,
      options.sourceDateEpoch,
    );
  }
  for (const document of INVENTORY_DOCUMENTS) {
    const path = join(repositoryRoot, "docs/ritual-investing", document);
    const contents = await readFile(path);
    assertReleaseContentsSafe(document, contents);
    await writeStableFile(
      join(bundleDirectory, "snapshots/docs/ritual-investing", document),
      contents,
      options.sourceDateEpoch,
    );
  }

  const files = await inventoryFiles(bundleDirectory);
  const profiles = ENVIRONMENTS.map((environment, index) => ({
    ...digestEntries(files, `profiles/${environment}`),
    environment,
    identity: loadedProfiles[index]!.profile.identity,
  }));
  const trees = ENVIRONMENTS.map((environment) => ({
    ...digestEntries(files, `trees/${environment}`),
    environment,
    surfaces: SURFACES.map((surface) => ({
      ...digestEntries(files, `trees/${environment}/${surface}`),
      surface,
      probeManifestSha256: requiredProbeManifestDigest(probeManifestDigests, `${environment}/${surface}`),
    })),
  }));
  const snapshots: ReleaseManifest["snapshots"] = [
    { ...digestEntries(files, "snapshots/infra/terraform/ritual-investing"), name: "terraform" },
    { ...digestEntries(files, "snapshots/supabase/migrations"), name: "supabase-migrations" },
    { ...digestEntries(files, "snapshots/supabase/functions"), name: "supabase-functions" },
    { ...digestEntries(files, "snapshots/docs/ritual-investing"), name: "ritual-inventories" },
  ];
  const requiredBackendSourceSha256 = calculateBackendSourceSha256(
    snapshots[1]!.sha256,
    snapshots[2]!.sha256,
  );
  const backendDependencies: ReleaseManifest["backendDependencies"] = [];
  for (let environmentIndex = 0; environmentIndex < ENVIRONMENTS.length; environmentIndex += 1) {
    const environment = ENVIRONMENTS[environmentIndex]!;
    const profile = loadedProfiles[environmentIndex]!.profile;
    const profileSha256 = profiles[environmentIndex]!.sha256;
    for (const surface of SURFACES) {
      const dependency = profile.targets[surface].backendDependency;
      backendDependencies.push({
        environment,
        surface,
        classification: dependency.classification,
        requiredFingerprint: dependency.requiredFingerprint,
        requiredSourceSha256: surface === "landing" ? requiredBackendSourceSha256 : null,
        targetStatus: dependency.target.status,
        profileSha256,
      });
    }
  }

  const manifest = parseReleaseManifest({
    schemaVersion: 2,
    sourceDateEpoch: options.sourceDateEpoch,
    createdAt: new Date(options.sourceDateEpoch * 1000).toISOString(),
    subject: options.provenance.subject,
    controller: options.provenance.controller,
    tools: options.toolVersions,
    profiles,
    trees,
    snapshots,
    backendDependencies,
    files,
  });
  const manifestBytes = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`);
  const manifestPath = join(bundleDirectory, "release-manifest.json");
  await writeStableFile(manifestPath, manifestBytes, options.sourceDateEpoch);
  const manifestSha256 = createHash("sha256").update(manifestBytes).digest("hex");
  const archivePath = join(outputDirectory, "release-bundle.tar");
  const archive = await createDeterministicArchive(bundleDirectory, archivePath, options.sourceDateEpoch);
  return {
    bundleDirectory,
    archivePath,
    archiveSha256: createHash("sha256").update(archive).digest("hex"),
    manifest,
    manifestSha256,
  };
}

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (value === undefined || value === "") throw new Error(`${name} is required`);
  return value;
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const packageRoot = resolve(import.meta.dirname, "../..");
    const repositoryRoot = resolve(packageRoot, "..");
    const result = await buildReleaseBundle({
      repositoryRoot,
      packageRoot,
      outputDirectory: resolve(process.env.RELEASE_OUTPUT_DIRECTORY ?? join(packageRoot, "release")),
      sourceDateEpoch: Number(requiredEnvironment("SOURCE_DATE_EPOCH")),
      provenance: {
        subject: {
          repository: requiredEnvironment("GITHUB_REPOSITORY"),
          sha: requiredEnvironment("GITHUB_SHA"),
          runId: requiredEnvironment("GITHUB_RUN_ID"),
          attempt: Number(requiredEnvironment("GITHUB_RUN_ATTEMPT")),
        },
        controller: {
          workflow: requiredEnvironment("GITHUB_WORKFLOW"),
          ref: requiredEnvironment("GITHUB_REF"),
          sha: requiredEnvironment("GITHUB_SHA"),
          runId: requiredEnvironment("GITHUB_RUN_ID"),
          attempt: Number(requiredEnvironment("GITHUB_RUN_ATTEMPT")),
        },
      },
      toolVersions: {
        node: process.versions.node,
        assetBuilder: "ritual-build-assets-v1",
        archive: "ustar-v1",
        terraform: "1.15.1",
        wrangler: "4.125.0",
        supabase: "2.115.0",
      },
    });
    process.stdout.write(`${JSON.stringify({
      archivePath: result.archivePath,
      archiveSha256: result.archiveSha256,
      manifestSha256: result.manifestSha256,
    })}\n`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Release bundle build failed");
    process.exitCode = 1;
  }
}
