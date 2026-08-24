import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(apiRoot, "..");
const clientRoot = resolve(repositoryRoot, "ritual-investing-api-client");
const generatorPath = resolve(
  apiRoot,
  "node_modules/@openapitools/openapi-generator-cli/main.js",
);
const dart = process.env.RITUAL_DART_BIN || "dart";

function run(command, arguments_, cwd) {
  const result = spawnSync(command, arguments_, { cwd, stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

run(
  process.execPath,
  [
    generatorPath,
    "--openapitools",
    "../ritual-investing-api-client/openapitools.json",
    "generate",
    "--generator-key",
    "ritual",
  ],
  apiRoot,
);
run(dart, ["pub", "get"], clientRoot);
run(
  dart,
  ["run", "build_runner", "build", "--delete-conflicting-outputs"],
  clientRoot,
);
run(dart, ["format", "lib", "test"], clientRoot);

const openapi = await readFile(
  resolve(apiRoot, "openapi/ritual-investing-v1.yaml"),
);
const pubspec = await readFile(resolve(clientRoot, "pubspec.yaml"), "utf8");
const version = /^version:\s*([^\s]+)$/m.exec(pubspec)?.[1];
if (version === undefined) throw new Error("generated client version is missing");
await writeFile(
  resolve(clientRoot, ".ritual-contract.json"),
  `${JSON.stringify(
    {
      schema_version: 1,
      openapi_sha256: createHash("sha256").update(openapi).digest("hex"),
      client_version: version,
      generator_image: "openapitools/openapi-generator-cli:v7.24.0",
    },
    null,
    2,
  )}\n`,
  "utf8",
);
