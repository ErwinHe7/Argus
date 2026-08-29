import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { stringify } from "yaml";

import {
  buildRetainedOpenApiDocument,
  createRetainedApp,
} from "../src/retained-app.ts";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const outputPath = resolve(
  scriptDirectory,
  "../openapi/ritual-investing-v1.yaml",
);

function sortValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortValue);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, sortValue(child)]),
    );
  }
  return value;
}

// Generation deliberately targets the clean Supabase contract. The legacy
// Worker factory remains executable until U13, but is not a source for new
// client artifacts and therefore cannot reintroduce Demo financial routes.
const contractApp = createRetainedApp({
  verifyAccessToken: async () => {
    throw new Error("contract_generation_does_not_verify_tokens");
  },
  withRepositories: () => {
    throw new Error("contract_generation_does_not_access_repositories");
  },
  withPublicPreview: () => {
    throw new Error("contract_generation_does_not_access_repositories");
  },
  createPrivacyService: () => {
    throw new Error("contract_generation_does_not_access_repositories");
  },
  rateLimit: {
    allow: async () => ({ allowed: true }),
  },
});
const document = sortValue(buildRetainedOpenApiDocument(contractApp));
const output = stringify(document, { lineWidth: 0 });
const checkOnly = process.argv.includes("--check");

if (checkOnly) {
  const existing = await readFile(outputPath, "utf8").catch(() => "");
  if (existing !== output) {
    console.error("OpenAPI snapshot is stale. Run npm run openapi:generate.");
    process.exitCode = 1;
  }
} else {
  await writeFile(outputPath, output, "utf8");
}
