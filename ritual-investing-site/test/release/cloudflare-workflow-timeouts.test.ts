import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../../..");
const workflows = [
  ".github/workflows/ritual-investing-staging.yml",
  ".github/workflows/ritual-investing-prod.yml",
] as const;

describe("Cloudflare deployment API timeout policy", () => {
  it.each(workflows)("bounds every Cloudflare API call in %s", async (workflow) => {
    const source = await readFile(resolve(root, workflow), "utf8");
    const calls = source.match(/curl\b(?:(?!\bcurl\b)[\s\S])*?api\.cloudflare\.com/g) ?? [];
    expect(calls.length).toBeGreaterThan(0);
    for (const call of calls) {
      expect(call).toContain("--connect-timeout 10");
      expect(call).toContain("--max-time 30");
    }
  });
});
