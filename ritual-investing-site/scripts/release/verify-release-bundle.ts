import { createHash } from "node:crypto";
import { lstat, readFile, readdir } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

export type ReleaseEnvironment = "staging" | "prod";
export type ReleaseSurface = "landing" | "demo";
export type BackendDependencyClass = "backend-independent" | "compatible-with" | "requires";

export type ReleaseSubjectIdentity = {
  repository: string;
  sha: string;
  runId: string;
  attempt: number;
};

export type ReleaseControllerIdentity = {
  workflow: string;
  ref: string;
  sha: string;
  runId: string;
  attempt: number;
};

export type BackendTarget =
  | { status: "approved"; supabaseProjectRef: string; waitlistUrl: string }
  | { status: "withheld"; reason: "approved-prod-target-not-configured" }
  | { status: "not-applicable" };

export type BackendDependency = {
  classification: BackendDependencyClass;
  requiredFingerprint: string | null;
  target: BackendTarget;
};

export type ReleaseTarget = {
  pagesProject: string;
  host: string;
  backendDependency: BackendDependency;
};

export type ReleaseProfile = {
  schemaVersion: 1;
  identity: string;
  environment: ReleaseEnvironment;
  targets: Record<ReleaseSurface, ReleaseTarget>;
};

export type ReleaseFileEntry = { path: string; bytes: number; sha256: string };
export type ReleaseDigestEntry = {
  root: string;
  fileCount: number;
  totalBytes: number;
  sha256: string;
};

export type ReleaseManifest = {
  schemaVersion: 1;
  sourceDateEpoch: number;
  createdAt: string;
  subject: ReleaseSubjectIdentity;
  controller: ReleaseControllerIdentity;
  tools: {
    node: string;
    assetBuilder: string;
    archive: string;
    terraform: string;
    wrangler: string;
    supabase: string;
  };
  profiles: Array<ReleaseDigestEntry & { environment: ReleaseEnvironment; identity: string }>;
  trees: Array<ReleaseDigestEntry & {
    environment: ReleaseEnvironment;
    surfaces: Array<ReleaseDigestEntry & {
      surface: ReleaseSurface;
      probeManifestSha256: string;
    }>;
  }>;
  snapshots: Array<ReleaseDigestEntry & {
    name: "terraform" | "supabase-migrations" | "supabase-functions" | "ritual-inventories";
  }>;
  backendDependencies: Array<{
    environment: ReleaseEnvironment;
    surface: ReleaseSurface;
    classification: BackendDependencyClass;
    requiredFingerprint: string | null;
    targetStatus: BackendTarget["status"];
    profileSha256: string;
  }>;
  files: ReleaseFileEntry[];
};

const ENVIRONMENTS = ["staging", "prod"] as const;
const SURFACES = ["landing", "demo"] as const;
const SHA256 = /^[a-f0-9]{64}$/;
const GIT_SHA = /^[a-f0-9]{40}$/;
const RUN_ID = /^[1-9][0-9]*$/;
const STAGING_SUPABASE_REF = "zbgjjufjkhfhirbuuolv";
const EXPECTED_TARGETS = {
  staging: {
    landing: { pagesProject: "ritual-investing-site-staging", host: "staging.just-build-this.app" },
    demo: { pagesProject: "ritual-investing-demo-staging", host: "demo-staging.just-build-this.app" },
  },
  prod: {
    landing: { pagesProject: "ritual-investing-member", host: "just-build-this.app" },
    demo: { pagesProject: "ritual-investing-demo", host: "demo.just-build-this.app" },
  },
} as const;

function backendTargetFingerprint(target: Extract<BackendTarget, { status: "approved" }>): string {
  return createHash("sha256")
    .update(`${target.supabaseProjectRef}\n${target.waitlistUrl}\n`)
    .digest("hex");
}

const SECRET_KEY = /secret|password|passwd|credential|private[_-]?key|service[_-]?role|access[_-]?key|api[_-]?key|auth[_-]?token/i;
const SECRET_VALUE_PATTERNS = [
  /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/,
  /\bsb_secret_(?!canary-)[A-Za-z0-9_-]{16,}\b/,
  /\bgh[oprsu]_[A-Za-z0-9]{20,}\b/,
  /\bAKIA[A-Z0-9]{16}\b/,
  /\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/,
];

function object(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value as Record<string, unknown>;
}

function exactKeys(value: Record<string, unknown>, allowed: readonly string[], label: string): void {
  const known = new Set(allowed);
  for (const key of Object.keys(value)) {
    if (!known.has(key)) throw new Error(`Unknown ${label} field: ${key}`);
  }
  for (const key of allowed) {
    if (!(key in value)) throw new Error(`Missing ${label} field: ${key}`);
  }
}

function nonempty(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim() === "" || value !== value.trim()) {
    throw new Error(`${label} must be a non-empty trimmed string`);
  }
  return value;
}

function integer(value: unknown, label: string, minimum = 0): number {
  if (!Number.isSafeInteger(value) || (value as number) < minimum) {
    throw new Error(`${label} must be an integer greater than or equal to ${minimum}`);
  }
  return value as number;
}

function hex(value: unknown, pattern: RegExp, label: string): string {
  if (typeof value !== "string" || !pattern.test(value)) throw new Error(`${label} has an invalid digest shape`);
  return value;
}

function assertNoSecretShape(value: unknown, label: string): void {
  if (typeof value === "string") {
    if (SECRET_VALUE_PATTERNS.some((pattern) => pattern.test(value))) {
      throw new Error(`${label} contains a secret-shaped value`);
    }
    try {
      const url = new URL(value);
      if (url.username !== "" || url.password !== "") throw new Error(`${label} contains URL credentials`);
    } catch (error) {
      if (error instanceof Error && error.message.includes("URL credentials")) throw error;
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((entry, index) => assertNoSecretShape(entry, `${label}[${index}]`));
    return;
  }
  if (value !== null && typeof value === "object") {
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
      if (SECRET_KEY.test(key)) throw new Error(`${label} contains a secret-shaped key: ${key}`);
      assertNoSecretShape(entry, `${label}.${key}`);
    }
  }
}

function parseSubject(value: unknown, label = "release subject"): ReleaseSubjectIdentity {
  const candidate = object(value, label);
  exactKeys(candidate, ["repository", "sha", "runId", "attempt"], label);
  const repository = nonempty(candidate.repository, `${label} repository`);
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)) throw new Error(`${label} repository is invalid`);
  const sha = hex(candidate.sha, GIT_SHA, `${label} SHA`);
  const runId = nonempty(candidate.runId, `${label} run ID`);
  if (!RUN_ID.test(runId)) throw new Error(`${label} run ID is invalid`);
  return { repository, sha, runId, attempt: integer(candidate.attempt, `${label} attempt`, 1) };
}

function parseController(value: unknown, label = "release controller"): ReleaseControllerIdentity {
  const candidate = object(value, label);
  exactKeys(candidate, ["workflow", "ref", "sha", "runId", "attempt"], label);
  const workflow = nonempty(candidate.workflow, `${label} workflow`);
  const ref = nonempty(candidate.ref, `${label} ref`);
  if (!ref.startsWith("refs/")) throw new Error(`${label} ref must be a full Git ref`);
  const sha = hex(candidate.sha, GIT_SHA, `${label} SHA`);
  const runId = nonempty(candidate.runId, `${label} run ID`);
  if (!RUN_ID.test(runId)) throw new Error(`${label} run ID is invalid`);
  return { workflow, ref, sha, runId, attempt: integer(candidate.attempt, `${label} attempt`, 1) };
}

export function parseReleaseSubject(value: unknown): ReleaseSubjectIdentity {
  return parseSubject(value);
}

export function parseReleaseController(value: unknown): ReleaseControllerIdentity {
  return parseController(value);
}

function parseBackendTarget(value: unknown, environment: ReleaseEnvironment, label: string): BackendTarget {
  const candidate = object(value, label);
  const status = candidate.status;
  if (status === "approved") {
    exactKeys(candidate, ["status", "supabaseProjectRef", "waitlistUrl"], label);
    const supabaseProjectRef = nonempty(candidate.supabaseProjectRef, `${label} Supabase project ref`);
    const waitlistUrl = nonempty(candidate.waitlistUrl, `${label} waitlist URL`);
    if (environment === "prod") {
      throw new Error("No approved prod Supabase target is configured; prod landing must remain withheld");
    }
    const exactUrl = `https://${STAGING_SUPABASE_REF}.supabase.co/functions/v1/waitlist`;
    if (supabaseProjectRef !== STAGING_SUPABASE_REF || waitlistUrl !== exactUrl) {
      throw new Error("Staging release profile contains an unapproved waitlist target");
    }
    return { status, supabaseProjectRef, waitlistUrl };
  }
  if (status === "withheld") {
    exactKeys(candidate, ["status", "reason"], label);
    if (environment !== "prod" || candidate.reason !== "approved-prod-target-not-configured") {
      throw new Error(`${label} may be withheld only for the unconfigured approved prod target`);
    }
    return { status, reason: "approved-prod-target-not-configured" };
  }
  if (status === "not-applicable") {
    exactKeys(candidate, ["status"], label);
    return { status };
  }
  throw new Error(`${label} status is unknown`);
}

function parseBackendDependency(
  value: unknown,
  environment: ReleaseEnvironment,
  surface: ReleaseSurface,
): BackendDependency {
  const label = `${environment} ${surface} backend dependency`;
  const candidate = object(value, label);
  exactKeys(candidate, ["classification", "requiredFingerprint", "target"], label);
  if (!(["backend-independent", "compatible-with", "requires"] as unknown[]).includes(candidate.classification)) {
    throw new Error(`${label} classification is unknown`);
  }
  const classification = candidate.classification as BackendDependencyClass;
  const requiredFingerprint = candidate.requiredFingerprint === null
    ? null
    : hex(candidate.requiredFingerprint, SHA256, `${label} required fingerprint`);
  const target = parseBackendTarget(candidate.target, environment, `${label} target`);

  if (surface === "demo") {
    if (classification !== "backend-independent" || requiredFingerprint !== null || target.status !== "not-applicable") {
      throw new Error(`${label} must remain backend-independent and target-free`);
    }
  } else if (classification === "backend-independent") {
    throw new Error(`${label} cannot classify landing as backend-independent`);
  } else if (target.status === "approved" && requiredFingerprint === null) {
    throw new Error(`${label} requires an exact backend fingerprint`);
  } else if (target.status === "approved" && requiredFingerprint !== backendTargetFingerprint(target)) {
    throw new Error(`${label} fingerprint does not match the canonical approved target identity`);
  } else if (target.status === "withheld" && (classification !== "requires" || requiredFingerprint !== null)) {
    throw new Error(`${label} withheld target must be an unresolved required dependency`);
  } else if (target.status === "not-applicable") {
    throw new Error(`${label} is missing its backend target`);
  }
  return { classification, requiredFingerprint, target };
}

export function parseReleaseProfile(value: unknown, expectedEnvironment?: ReleaseEnvironment): ReleaseProfile {
  assertNoSecretShape(value, "release profile");
  const candidate = object(value, "release profile");
  exactKeys(candidate, ["schemaVersion", "identity", "environment", "targets"], "release profile");
  if (candidate.schemaVersion !== 1) throw new Error("Release profile schemaVersion must be 1");
  if (candidate.environment !== "staging" && candidate.environment !== "prod") {
    throw new Error("Release profile environment must be staging or prod");
  }
  const environment = candidate.environment;
  if (expectedEnvironment !== undefined && environment !== expectedEnvironment) {
    throw new Error(`Release profile environment must be ${expectedEnvironment}`);
  }
  const identity = nonempty(candidate.identity, "Release profile identity");
  const targets = object(candidate.targets, "release profile targets");
  exactKeys(targets, SURFACES, "release profile targets");
  const parsedTargets = {} as Record<ReleaseSurface, ReleaseTarget>;
  for (const surface of SURFACES) {
    const label = `${environment} ${surface} target`;
    const target = object(targets[surface], label);
    exactKeys(target, ["pagesProject", "host", "backendDependency"], label);
    const pagesProject = nonempty(target.pagesProject, `${label} Pages project`);
    const host = nonempty(target.host, `${label} host`);
    if (environment === "prod" && /staging/i.test(`${pagesProject} ${host}`)) {
      throw new Error(`${label} must not contain a staging target`);
    }
    const expected = EXPECTED_TARGETS[environment][surface];
    if (pagesProject !== expected.pagesProject || host !== expected.host) {
      throw new Error(`${label} must use the exact reviewed ${environment} Pages project and host`);
    }
    parsedTargets[surface] = {
      pagesProject,
      host,
      backendDependency: parseBackendDependency(target.backendDependency, environment, surface),
    };
  }
  return { schemaVersion: 1, identity, environment, targets: parsedTargets };
}

export function profileReleaseEligibility(profile: ReleaseProfile): {
  demo: boolean;
  landing: boolean;
  full: boolean;
} {
  const demo = profile.targets.demo.backendDependency.classification === "backend-independent";
  const landing = profile.targets.landing.backendDependency.target.status === "approved" &&
    profile.targets.landing.backendDependency.requiredFingerprint !== null;
  return { demo, landing, full: demo && landing };
}

function parseFileEntry(value: unknown, label: string): ReleaseFileEntry {
  const candidate = object(value, label);
  exactKeys(candidate, ["path", "bytes", "sha256"], label);
  return {
    path: safeRelativePath(nonempty(candidate.path, `${label} path`)),
    bytes: integer(candidate.bytes, `${label} bytes`),
    sha256: hex(candidate.sha256, SHA256, `${label} SHA-256`),
  };
}

function parseDigestEntry(value: unknown, extraKeys: readonly string[], label: string): ReleaseDigestEntry & Record<string, unknown> {
  const candidate = object(value, label);
  exactKeys(candidate, ["root", "fileCount", "totalBytes", "sha256", ...extraKeys], label);
  return {
    ...candidate,
    root: safeRelativePath(nonempty(candidate.root, `${label} root`)),
    fileCount: integer(candidate.fileCount, `${label} fileCount`),
    totalBytes: integer(candidate.totalBytes, `${label} totalBytes`),
    sha256: hex(candidate.sha256, SHA256, `${label} SHA-256`),
  };
}

function assertOrderedUnique(values: readonly string[], label: string): void {
  const expected = [...values].sort((left, right) => left.localeCompare(right));
  if (new Set(values).size !== values.length || values.some((value, index) => value !== expected[index])) {
    throw new Error(`${label} must be ordered and unique`);
  }
}

export function calculateProbeManifestSha256(entries: readonly ReleaseFileEntry[]): string {
  const deployable = entries
    .filter(({ path }) => path !== "version.json" && path !== "asset-manifest.json")
    .sort((left, right) => left.path.localeCompare(right.path));
  if (deployable.length === 0) throw new Error("Probe content manifest cannot be empty");
  assertOrderedUnique(deployable.map(({ path }) => path), "Probe content manifest paths");
  const canonical = deployable.map(({ path, bytes, sha256 }) => `${sha256} ${bytes} ${path}\n`).join("");
  return createHash("sha256").update(canonical).digest("hex");
}

function parseProbeVersion(value: unknown, label: string): {
  schemaVersion: 1;
  revision: string;
  manifestSha256: string;
} {
  const candidate = object(value, label);
  exactKeys(candidate, ["schemaVersion", "revision", "manifestSha256"], label);
  if (candidate.schemaVersion !== 1) throw new Error(`${label} schemaVersion must be 1`);
  return {
    schemaVersion: 1,
    revision: hex(candidate.revision, GIT_SHA, `${label} revision`),
    manifestSha256: hex(candidate.manifestSha256, SHA256, `${label} manifest SHA-256`),
  };
}

function parseAssetManifest(value: unknown, label: string): {
  algorithm: "sha256";
  fileCount: number;
  totalBytes: number;
  files: ReleaseFileEntry[];
} {
  const candidate = object(value, label);
  exactKeys(candidate, ["algorithm", "fileCount", "totalBytes", "files"], label);
  if (candidate.algorithm !== "sha256") throw new Error(`${label} algorithm must be sha256`);
  if (!Array.isArray(candidate.files)) throw new Error(`${label} files must be an array`);
  const files = candidate.files.map((entry, index) => parseFileEntry(entry, `${label} file ${index}`));
  assertOrderedUnique(files.map(({ path }) => path), `${label} file paths`);
  const fileCount = integer(candidate.fileCount, `${label} fileCount`);
  const totalBytes = integer(candidate.totalBytes, `${label} totalBytes`);
  if (fileCount !== files.length || totalBytes !== files.reduce((sum, entry) => sum + entry.bytes, 0)) {
    throw new Error(`${label} inventory totals do not match its files`);
  }
  return { algorithm: "sha256", fileCount, totalBytes, files };
}

export function parseReleaseManifest(value: unknown): ReleaseManifest {
  const candidate = object(value, "release manifest");
  exactKeys(candidate, [
    "schemaVersion", "sourceDateEpoch", "createdAt", "subject", "controller", "tools",
    "profiles", "trees", "snapshots", "backendDependencies", "files",
  ], "release manifest");
  if (candidate.schemaVersion !== 1) throw new Error("Release manifest schemaVersion must be 1");
  const sourceDateEpoch = integer(candidate.sourceDateEpoch, "release manifest sourceDateEpoch");
  const createdAt = nonempty(candidate.createdAt, "release manifest createdAt");
  if (createdAt !== new Date(sourceDateEpoch * 1000).toISOString()) {
    throw new Error("Release manifest createdAt must exactly match sourceDateEpoch");
  }
  const tools = object(candidate.tools, "release manifest tools");
  exactKeys(tools, ["node", "assetBuilder", "archive", "terraform", "wrangler", "supabase"], "release manifest tools");
  const parsedTools = {
    node: nonempty(tools.node, "Node version"),
    assetBuilder: nonempty(tools.assetBuilder, "asset builder version"),
    archive: nonempty(tools.archive, "archive version"),
    terraform: nonempty(tools.terraform, "Terraform version"),
    wrangler: nonempty(tools.wrangler, "Wrangler version"),
    supabase: nonempty(tools.supabase, "Supabase version"),
  };

  if (!Array.isArray(candidate.files)) throw new Error("Release manifest files must be an array");
  const files = candidate.files.map((entry, index) => parseFileEntry(entry, `release file ${index}`));
  assertOrderedUnique(files.map(({ path }) => path), "Release manifest file paths");

  if (!Array.isArray(candidate.profiles) || candidate.profiles.length !== 2) throw new Error("Release manifest must contain staging and prod profiles");
  const profiles = candidate.profiles.map((entry, index) => {
    const parsed = parseDigestEntry(entry, ["environment", "identity"], `release profile digest ${index}`);
    if (parsed.environment !== ENVIRONMENTS[index]) throw new Error("Release manifest profiles must be ordered staging then prod");
    if (parsed.root !== `profiles/${parsed.environment}`) throw new Error("Release profile digest root is not canonical");
    return {
      root: parsed.root,
      fileCount: parsed.fileCount,
      totalBytes: parsed.totalBytes,
      sha256: parsed.sha256,
      environment: parsed.environment as ReleaseEnvironment,
      identity: nonempty(parsed.identity, `release profile digest ${index} identity`),
    };
  });

  if (!Array.isArray(candidate.trees) || candidate.trees.length !== 2) throw new Error("Release manifest must contain staging and prod trees");
  const trees = candidate.trees.map((entry, index) => {
    const parsed = parseDigestEntry(entry, ["environment", "surfaces"], `release tree ${index}`);
    if (parsed.environment !== ENVIRONMENTS[index]) throw new Error("Release trees must be ordered staging then prod");
    if (parsed.root !== `trees/${parsed.environment}`) throw new Error("Release tree root is not canonical");
    if (!Array.isArray(parsed.surfaces) || parsed.surfaces.length !== 2) throw new Error("Each release tree must contain landing and demo surfaces");
    const surfaces = parsed.surfaces.map((surfaceEntry, surfaceIndex) => {
      const surface = parseDigestEntry(
        surfaceEntry,
        ["surface", "probeManifestSha256"],
        `release tree ${index} surface ${surfaceIndex}`,
      );
      if (surface.surface !== SURFACES[surfaceIndex]) throw new Error("Release surfaces must be ordered landing then demo");
      if (surface.root !== `trees/${parsed.environment}/${surface.surface}`) throw new Error("Release surface root is not canonical");
      return {
        root: surface.root,
        fileCount: surface.fileCount,
        totalBytes: surface.totalBytes,
        sha256: surface.sha256,
        surface: surface.surface as ReleaseSurface,
        probeManifestSha256: hex(
          surface.probeManifestSha256,
          SHA256,
          `release tree ${index} surface ${surfaceIndex} probe manifest SHA-256`,
        ),
      };
    });
    return {
      root: parsed.root,
      fileCount: parsed.fileCount,
      totalBytes: parsed.totalBytes,
      sha256: parsed.sha256,
      environment: parsed.environment as ReleaseEnvironment,
      surfaces,
    };
  });

  const snapshotNames = ["terraform", "supabase-migrations", "supabase-functions", "ritual-inventories"] as const;
  if (!Array.isArray(candidate.snapshots) || candidate.snapshots.length !== snapshotNames.length) {
    throw new Error("Release manifest snapshot inventory is incomplete");
  }
  const snapshots = candidate.snapshots.map((entry, index) => {
    const parsed = parseDigestEntry(entry, ["name"], `release snapshot ${index}`);
    if (parsed.name !== snapshotNames[index]) throw new Error("Release snapshots must use the canonical order");
    const expectedRoots = [
      "snapshots/infra/terraform/ritual-investing",
      "snapshots/supabase/migrations",
      "snapshots/supabase/functions",
      "snapshots/docs/ritual-investing",
    ] as const;
    if (parsed.root !== expectedRoots[index]) throw new Error("Release snapshot root is not canonical");
    return {
      root: parsed.root,
      fileCount: parsed.fileCount,
      totalBytes: parsed.totalBytes,
      sha256: parsed.sha256,
      name: parsed.name as (typeof snapshotNames)[number],
    };
  });

  if (!Array.isArray(candidate.backendDependencies) || candidate.backendDependencies.length !== 4) {
    throw new Error("Release manifest backend dependency inventory is incomplete");
  }
  const backendDependencies = candidate.backendDependencies.map((entry, index) => {
    const dependency = object(entry, `backend dependency ${index}`);
    exactKeys(dependency, [
      "environment", "surface", "classification", "requiredFingerprint", "targetStatus", "profileSha256",
    ], `backend dependency ${index}`);
    const environment = ENVIRONMENTS[Math.floor(index / 2)];
    const surface = SURFACES[index % 2];
    if (environment === undefined || surface === undefined) {
      throw new Error("Backend dependency inventory index is invalid");
    }
    if (dependency.environment !== environment || dependency.surface !== surface) {
      throw new Error("Backend dependencies must be ordered by environment and surface");
    }
    if (!(["backend-independent", "compatible-with", "requires"] as unknown[]).includes(dependency.classification)) {
      throw new Error(`Backend dependency ${index} classification is unknown`);
    }
    if (!(["approved", "withheld", "not-applicable"] as unknown[]).includes(dependency.targetStatus)) {
      throw new Error(`Backend dependency ${index} target status is unknown`);
    }
    return {
      environment,
      surface,
      classification: dependency.classification as BackendDependencyClass,
      requiredFingerprint: dependency.requiredFingerprint === null
        ? null
        : hex(dependency.requiredFingerprint, SHA256, `backend dependency ${index} fingerprint`),
      targetStatus: dependency.targetStatus as BackendTarget["status"],
      profileSha256: hex(dependency.profileSha256, SHA256, `backend dependency ${index} profile SHA-256`),
    };
  });

  return {
    schemaVersion: 1,
    sourceDateEpoch,
    createdAt,
    subject: parseSubject(candidate.subject),
    controller: parseController(candidate.controller),
    tools: parsedTools,
    profiles,
    trees,
    snapshots,
    backendDependencies,
    files,
  };
}

function posixPath(value: string): string {
  return value.split(sep).join("/");
}

function safeRelativePath(value: string): string {
  if (value.startsWith("/") || value === ".." || value.startsWith("../") || value.includes("/../") || value.includes("\\")) {
    throw new Error(`Unsafe release path: ${value}`);
  }
  return value;
}

export function isExcludedReleaseSource(path: string): boolean {
  const normalized = `/${posixPath(path)}`;
  const base = normalized.slice(normalized.lastIndexOf("/") + 1);
  return normalized.split("/").includes(".terraform") ||
    normalized.split("/").some((part) => ["node_modules", ".wrangler", ".cache", "coverage", "test-results"].includes(part)) ||
    /^\.env(?:\.|$)/i.test(base) ||
    /(?:^|\.)(?:tfstate|tfplan)(?:\.|$)/i.test(base) ||
    /(?:^|[-_.])(?:plan|state)\.(?:json|bin)$/i.test(base) ||
    /(?:^|\/)\.DS_Store$/i.test(normalized);
}

export function isSecretShapedReleasePath(path: string): boolean {
  const base = posixPath(path).slice(posixPath(path).lastIndexOf("/") + 1);
  return /(?:^|[-_.])(?:credentials?|secrets?)(?:[-_.]|$)/i.test(base) ||
    /(?:^|[-_.])private(?:[-_.]|$).+\.(?:pem|key|p12|pfx|jks)$/i.test(base) ||
    /^(?:id_rsa|id_ed25519)(?:\.pub)?$/i.test(base) ||
    /\.(?:pem|p12|pfx|jks)$/i.test(base) ||
    /(?:^|\/)\.npmrc$/i.test(posixPath(path));
}

export function assertReleaseContentsSafe(path: string, contents: Uint8Array): void {
  if (isSecretShapedReleasePath(path)) throw new Error(`Secret-shaped credential file is forbidden: ${path}`);
  const text = new TextDecoder().decode(contents);
  if (SECRET_VALUE_PATTERNS.some((pattern) => pattern.test(text))) {
    throw new Error(`Secret or private key material is forbidden in release source: ${path}`);
  }
}

async function walk(root: string, directory = root): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const paths: string[] = [];
  for (const entry of entries.sort((left, right) => left.name.localeCompare(right.name))) {
    const absolute = join(directory, entry.name);
    const metadata = await lstat(absolute);
    if (metadata.isSymbolicLink()) throw new Error(`Release bundle cannot contain symlinks: ${posixPath(relative(root, absolute))}`);
    if (metadata.isDirectory()) paths.push(...await walk(root, absolute));
    else if (metadata.isFile()) paths.push(posixPath(relative(root, absolute)));
  }
  return paths.sort((left, right) => left.localeCompare(right));
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

function sameDigest(expected: ReleaseDigestEntry, actual: ReleaseDigestEntry, label: string): void {
  if (expected.root !== actual.root || expected.fileCount !== actual.fileCount ||
      expected.totalBytes !== actual.totalBytes || expected.sha256 !== actual.sha256) {
    throw new Error(`${label} digest or inventory mismatch`);
  }
}

function sameIdentity(expected: Record<string, unknown>, actual: Record<string, unknown>, label: string): void {
  for (const [key, value] of Object.entries(expected)) {
    if (actual[key] !== value) throw new Error(`${label} ${key} mismatch`);
  }
}

function sameFileInventory(
  expected: readonly ReleaseFileEntry[],
  actual: readonly ReleaseFileEntry[],
  label: string,
): void {
  if (expected.length !== actual.length || expected.some((entry, index) => {
    const observed = actual[index];
    return observed === undefined || entry.path !== observed.path || entry.bytes !== observed.bytes ||
      entry.sha256 !== observed.sha256;
  })) {
    throw new Error(`${label} does not match the exact deployable tree inventory`);
  }
}

export type BundleVerificationContext = {
  expectedSubject?: ReleaseSubjectIdentity;
  expectedController?: ReleaseControllerIdentity;
};

export async function verifyReleaseBundle(
  bundleDirectory: string,
  context: BundleVerificationContext = {},
): Promise<{ manifest: ReleaseManifest; manifestSha256: string }> {
  const root = resolve(bundleDirectory);
  const manifestBytes = await readFile(join(root, "release-manifest.json"));
  const manifest = parseReleaseManifest(JSON.parse(manifestBytes.toString("utf8")));
  const manifestSha256 = createHash("sha256").update(manifestBytes).digest("hex");
  if (context.expectedSubject !== undefined) sameIdentity(context.expectedSubject, manifest.subject, "Release subject");
  if (context.expectedController !== undefined) sameIdentity(context.expectedController, manifest.controller, "Release controller");

  const paths = (await walk(root)).filter((path) => path !== "release-manifest.json");
  if (paths.length !== manifest.files.length || paths.some((path, index) => path !== manifest.files[index]?.path)) {
    throw new Error("Release bundle file inventory does not exactly match the manifest");
  }
  const actualFiles: ReleaseFileEntry[] = [];
  for (const path of paths) {
    if (isExcludedReleaseSource(path) || isSecretShapedReleasePath(path)) {
      throw new Error(`Forbidden release bundle path: ${path}`);
    }
    const contents = await readFile(join(root, path));
    assertReleaseContentsSafe(path, contents);
    const actual = {
      path,
      bytes: contents.byteLength,
      sha256: createHash("sha256").update(contents).digest("hex"),
    };
    const expected = manifest.files[actualFiles.length];
    if (expected === undefined || actual.bytes !== expected.bytes || actual.sha256 !== expected.sha256) {
      throw new Error(`Release bundle checksum mismatch: ${path}`);
    }
    actualFiles.push(actual);
  }

  const verifiedProfiles = new Map<ReleaseEnvironment, ReleaseProfile>();
  for (const profileDigest of manifest.profiles) {
    sameDigest(profileDigest, digestEntries(actualFiles, profileDigest.root), `${profileDigest.environment} profile`);
    const profilePath = `${profileDigest.root}/profile.json`;
    const profile = parseReleaseProfile(JSON.parse(await readFile(join(root, profilePath), "utf8")), profileDigest.environment);
    if (profile.identity !== profileDigest.identity) throw new Error(`${profileDigest.environment} profile identity mismatch`);
    verifiedProfiles.set(profileDigest.environment, profile);
  }
  for (const tree of manifest.trees) {
    sameDigest(tree, digestEntries(actualFiles, tree.root), `${tree.environment} tree`);
    for (const surface of tree.surfaces) {
      const label = `${tree.environment} ${surface.surface}`;
      sameDigest(surface, digestEntries(actualFiles, surface.root), `${label} tree`);
      const prefix = `${surface.root}/`;
      const surfaceFiles = actualFiles
        .filter(({ path }) => path.startsWith(prefix))
        .map(({ path, bytes, sha256 }) => ({ path: path.slice(prefix.length), bytes, sha256 }));
      const probeManifestSha256 = calculateProbeManifestSha256(surfaceFiles);
      if (probeManifestSha256 !== surface.probeManifestSha256) {
        throw new Error(`${label} probe content manifest digest mismatch`);
      }
      const version = parseProbeVersion(
        JSON.parse(await readFile(join(root, surface.root, "version.json"), "utf8")),
        `${label} version marker`,
      );
      if (version.revision !== manifest.subject.sha || version.manifestSha256 !== probeManifestSha256) {
        throw new Error(`${label} version marker identity mismatch`);
      }
      const assetManifest = parseAssetManifest(
        JSON.parse(await readFile(join(root, surface.root, "asset-manifest.json"), "utf8")),
        `${label} asset manifest`,
      );
      const expectedAssetFiles = surfaceFiles.filter(({ path }) => path !== "asset-manifest.json");
      if (!assetManifest.files.some(({ path }) => path === "version.json")) {
        throw new Error(`${label} asset manifest omits the version marker`);
      }
      sameFileInventory(assetManifest.files, expectedAssetFiles, `${label} asset manifest`);
    }
  }
  for (const snapshot of manifest.snapshots) {
    sameDigest(snapshot, digestEntries(actualFiles, snapshot.root), `${snapshot.name} snapshot`);
  }
  for (const dependency of manifest.backendDependencies) {
    const profile = verifiedProfiles.get(dependency.environment);
    const profileDigest = manifest.profiles.find(({ environment }) => environment === dependency.environment);
    if (profile === undefined || profileDigest === undefined) throw new Error("Backend dependency profile is missing");
    const expected = profile.targets[dependency.surface].backendDependency;
    if (dependency.classification !== expected.classification ||
        dependency.requiredFingerprint !== expected.requiredFingerprint ||
        dependency.targetStatus !== expected.target.status ||
        dependency.profileSha256 !== profileDigest.sha256) {
      throw new Error(`${dependency.environment} ${dependency.surface} backend dependency fingerprint mismatch`);
    }
  }
  return { manifest, manifestSha256 };
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const bundleDirectory = process.argv[2];
    if (bundleDirectory === undefined) throw new Error("Usage: verify-release-bundle.ts <bundle-directory>");
    const contextJson = process.env.RELEASE_BUNDLE_VERIFICATION_CONTEXT;
    const context = contextJson === undefined
      ? {}
      : JSON.parse(contextJson) as BundleVerificationContext;
    const result = await verifyReleaseBundle(bundleDirectory, context);
    process.stdout.write(`${JSON.stringify({
      manifestSha256: result.manifestSha256,
      subject: result.manifest.subject,
      controller: result.manifest.controller,
    })}\n`);
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Release bundle verification failed");
    process.exitCode = 1;
  }
}
