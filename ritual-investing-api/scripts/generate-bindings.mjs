import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputPath = resolve(apiRoot, "src/generated/env.d.ts");
const wranglerPath = resolve(apiRoot, "node_modules/wrangler/bin/wrangler.js");

const result = spawnSync(process.execPath, [wranglerPath, "types", outputPath], {
  cwd: apiRoot,
  stdio: "inherit",
});

if (result.status !== 0) process.exit(result.status ?? 1);

const normalized = readFileSync(outputPath, "utf8")
  .replace(/[\t ]+$/gm, "")
  .replace(/\n*$/, "\n");
writeFileSync(outputPath, normalized, "utf8");
