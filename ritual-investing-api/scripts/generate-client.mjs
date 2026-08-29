import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFile, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(apiRoot, "..");
const clientRoot = resolve(repositoryRoot, "ritual-investing-api-client");
const openApiPath = resolve(apiRoot, "openapi/ritual-investing-v1.yaml");
const templateRoot = resolve(clientRoot, "templates/dart-dio");
const dart = process.env.RITUAL_DART_BIN || "dart";
const dockerUser =
  typeof process.getuid === "function" && typeof process.getgid === "function"
    ? ["--user", `${process.getuid()}:${process.getgid()}`]
    : [];

function run(command, arguments_, cwd) {
  const result = spawnSync(command, arguments_, { cwd, stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

async function generatedFiles() {
  try {
    return new Set(
      (await readFile(resolve(clientRoot, ".openapi-generator/FILES"), "utf8"))
        .split("\n")
        .filter((path) =>
          path.startsWith("doc/") || path.startsWith("lib/generated/")
        ),
    );
  } catch (error) {
    if (error?.code === "ENOENT") return new Set();
    throw error;
  }
}

// Keep the last generated client intact if Docker cannot start or generation
// fails. Once a new generation succeeds, its manifest lets us remove only
// obsolete generator-owned docs and Dart sources.
const previousGeneratedFiles = await generatedFiles();

run(
  "docker",
  [
    "run",
    "--rm",
    ...dockerUser,
    "-v",
    `${openApiPath}:/input/ritual-investing-v1.yaml:ro`,
    "-v",
    `${templateRoot}:/templates/dart-dio:ro`,
    "-v",
    `${clientRoot}:/output`,
    "openapitools/openapi-generator-cli:v7.24.0",
    "generate",
    "-g",
    "dart-dio",
    "-i",
    "/input/ritual-investing-v1.yaml",
    "-o",
    "/output",
    "-t",
    "/templates/dart-dio",
    "--global-property",
    "apiTests=false,modelTests=false",
    "--additional-properties",
    "pubName=ritual_investing_api_client,pubVersion=0.2.0,pubPublishTo=none,sourceFolder=generated,serializationLibrary=json_serializable,useEnumExtension=true,enumUnknownDefaultCase=true,disallowAdditionalPropertiesIfNotPresent=false",
  ],
  repositoryRoot,
);

const regeneratedFiles = await generatedFiles();
await Promise.all(
  [...previousGeneratedFiles]
    .filter((path) => !regeneratedFiles.has(path))
    .map((path) => rm(resolve(clientRoot, path), { force: true })),
);

// OpenAPI Generator 7.24 correctly types an OAS binary request as
// MultipartFile but its dart-dio template still JSON-encodes that value. Keep
// the workaround in the reproducible generation pipeline until the pinned
// upstream generator emits raw binary request bodies itself.
const mediaApiPath = resolve(
  clientRoot,
  "lib/generated/api/media_api.dart",
);
const mediaApi = await readFile(mediaApiPath, "utf8");
const uploadMethod = mediaApi.indexOf(
  "Future<Response<void>> uploadMediaQuarantineContent",
);
if (uploadMethod >= 0) {
  const encodedBodyStart = mediaApi.indexOf(
    "    dynamic _bodyData;",
    uploadMethod,
  );
  const requestStart = mediaApi.indexOf(
    "    final _response",
    encodedBodyStart,
  );
  const encodedBody = mediaApi.slice(encodedBodyStart, requestStart);
  if (
    encodedBodyStart < 0 ||
    requestStart < 0 ||
    !encodedBody.includes("jsonEncode(body)")
  ) {
    throw new Error(
      "generated binary upload shape changed; review the workaround",
    );
  }
  await writeFile(
    mediaApiPath,
    `${
      mediaApi.slice(0, encodedBodyStart)
    }    final _bodyData = body;\n\n${mediaApi.slice(requestStart)}`,
    "utf8",
  );
}
run(dart, ["pub", "get"], clientRoot);
run(
  dart,
  ["run", "build_runner", "build", "--delete-conflicting-outputs"],
  clientRoot,
);
run(dart, ["format", "lib", "test"], clientRoot);

const openapi = await readFile(
  openApiPath,
);
const pubspec = await readFile(resolve(clientRoot, "pubspec.yaml"), "utf8");
const version = /^version:\s*([^\s]+)$/m.exec(pubspec)?.[1];
if (version === undefined) {
  throw new Error("generated client version is missing");
}
await writeFile(
  resolve(clientRoot, ".ritual-contract.json"),
  `${
    JSON.stringify(
      {
        schema_version: 1,
        openapi_sha256: createHash("sha256").update(openapi).digest("hex"),
        client_version: version,
        generator_image: "openapitools/openapi-generator-cli:v7.24.0",
      },
      null,
      2,
    )
  }\n`,
  "utf8",
);
