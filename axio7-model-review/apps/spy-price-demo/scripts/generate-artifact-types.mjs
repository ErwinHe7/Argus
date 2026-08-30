import { access, mkdir, readdir, unlink, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { compileFromFile } from "json-schema-to-typescript";

const schemaDirectory = new URL(
  "../../../contracts/spy-price-demo/v1/",
  import.meta.url,
);
const generatedDirectory = new URL(
  "../src/features/replay/artifact/generated/",
  import.meta.url,
);
const bannerComment =
  "/* This file is generated from the canonical JSON Schema. Do not edit. */";

const artifacts = [
  ["manifest.schema.json", "manifest.ts"],
  ["session-index.schema.json", "sessionIndex.ts"],
  ["session.schema.json", "session.ts"],
  ["summary.schema.json", "summary.ts"],
  ["model-card.schema.json", "modelCard.ts"],
];

const contracts = `${bannerComment}
export type { Manifest } from "./manifest";
export type {
  SessionIndexArtifact,
  SessionIndexEntry,
} from "./sessionIndex";
export type { ChartBar, ReplayRow, SessionArtifact } from "./session";
export type { SummaryArtifact } from "./summary";
export type { ModelCard } from "./modelCard";
`;

async function main() {
  const compiled = await Promise.all(
    artifacts.map(async ([schemaName, outputName]) => {
      const schemaUrl = new URL(schemaName, schemaDirectory);
      await access(schemaUrl);
      const source = await compileFromFile(fileURLToPath(schemaUrl), {
        bannerComment,
        cwd: fileURLToPath(schemaDirectory),
        unknownAny: true,
      });
      return [outputName, source];
    }),
  );

  await mkdir(generatedDirectory, { recursive: true });
  const existingFiles = await readdir(generatedDirectory, {
    withFileTypes: true,
  });
  await Promise.all(
    existingFiles
      .filter((entry) => entry.isFile() && entry.name.endsWith(".ts"))
      .map((entry) => unlink(new URL(entry.name, generatedDirectory))),
  );

  await Promise.all([
    ...compiled.map(([outputName, source]) =>
      writeFile(new URL(outputName, generatedDirectory), source, "utf8"),
    ),
    writeFile(
      new URL("contracts.ts", generatedDirectory),
      contracts,
      "utf8",
    ),
  ]);

  console.log(`Generated ${compiled.length + 1} artifact type modules.`);
}

await main();
