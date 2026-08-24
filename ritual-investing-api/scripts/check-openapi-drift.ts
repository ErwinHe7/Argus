import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

interface CoupledArtifacts {
  openapi: string;
  client: string;
}

export function fingerprintArtifact(content: string | Buffer): string {
  return createHash("sha256").update(content).digest("hex");
}

export function assertCoupledArtifacts(
  before: CoupledArtifacts,
  after: CoupledArtifacts,
): void {
  const openapiChanged = before.openapi !== after.openapi;
  const clientChanged = before.client !== after.client;
  if (openapiChanged !== clientChanged) {
    throw new Error(
      "OpenAPI and generated client artifacts must move together",
    );
  }
}

function run(command: string, arguments_: string[], cwd: string): string {
  const result = spawnSync(command, arguments_, {
    cwd,
    encoding: "utf8",
    env: process.env,
  });
  if (result.error !== undefined) throw result.error;
  if (result.status !== 0) {
    throw new Error(
      `${command} ${arguments_.join(" ")} failed:\n${result.stderr || result.stdout}`,
    );
  }
  return result.stdout;
}

async function snapshotGeneratedArtifacts(
  repositoryRoot: string,
): Promise<Map<string, string>> {
  const clientRoot = resolve(repositoryRoot, "ritual-investing-api-client");
  const generatedFiles = (
    await readFile(resolve(clientRoot, ".openapi-generator/FILES"), "utf8")
  )
    .split("\n")
    .map((value) => value.trim())
    .filter(Boolean);
  const relativePaths = [
    ...generatedFiles.map((path) => `ritual-investing-api-client/${path}`),
    "ritual-investing-api-client/.openapi-generator/FILES",
    "ritual-investing-api-client/.ritual-contract.json",
    "ritual-investing-api-client/README.md",
    "ritual-investing-api-client/pubspec.yaml",
    "ritual-investing-api/openapi/ritual-investing-v1.yaml",
  ];
  return new Map(
    await Promise.all(
      [...new Set(relativePaths)]
        .sort()
        .map(
          async (path) =>
            [
              path,
              fingerprintArtifact(
                await readFile(resolve(repositoryRoot, path)),
              ),
            ] as const,
        ),
    ),
  );
}

async function main(): Promise<void> {
  const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
  const repositoryRoot = resolve(apiRoot, "..");
  const openapiPath = resolve(apiRoot, "openapi/ritual-investing-v1.yaml");
  const manifestPath = resolve(
    repositoryRoot,
    "ritual-investing-api-client/.ritual-contract.json",
  );
  run("npm", ["run", "openapi:check"], apiRoot);
  const before = await snapshotGeneratedArtifacts(repositoryRoot);
  run("npm", ["run", "client:generate"], apiRoot);
  const after = await snapshotGeneratedArtifacts(repositoryRoot);
  if (
    before.size !== after.size ||
    [...before].some(([path, fingerprint]) => after.get(path) !== fingerprint)
  ) {
    throw new Error("client generation changed committed contract artifacts");
  }

  const [openapi, manifestText] = await Promise.all([
    readFile(openapiPath),
    readFile(manifestPath, "utf8"),
  ]);
  const manifest = JSON.parse(manifestText) as { openapi_sha256?: unknown };
  if (manifest.openapi_sha256 !== fingerprintArtifact(openapi)) {
    throw new Error("generated client manifest does not match OpenAPI");
  }
  process.stdout.write("OpenAPI and generated Dart client are drift-free\n");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  await main();
}
