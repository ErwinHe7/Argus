import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { dirname, relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");

function repositoryPath(absolutePath: string): string {
  return relative(repositoryRoot, absolutePath).replaceAll("\\", "/");
}

describe("portable API runtime import boundary", () => {
  it("keeps every accepted Edge/shared transitive import free of legacy runtimes", async () => {
    const sharedModules = (await readdir(
      resolve(repositoryRoot, "supabase/functions/_shared"),
    ))
      .filter((path) => path.endsWith(".ts"))
      .map((path) => `supabase/functions/_shared/${path}`);
    const acceptedEntries = [
      "supabase/functions/api/index.ts",
      ...sharedModules,
      "ritual-investing-api/src/retained-app.ts",
    ];
    const forbidden = [
      "@neondatabase/serverless",
      "@cloudflare/",
      "@auth0/",
      "cloudflare-access",
      "auth0-jwk",
      "cloudflare:workers",
      "wrangler",
      "R2Bucket",
      "config/env",
      "src/app.ts",
    ];
    const visited = new Set<string>();

    const visit = async (absolutePath: string): Promise<void> => {
      if (visited.has(absolutePath)) return;
      visited.add(absolutePath);
      const source = await readFile(absolutePath, "utf8");
      const displayPath = repositoryPath(absolutePath);

      for (const marker of forbidden) {
        expect(
          source,
          `${displayPath} imports or declares ${marker}`,
        ).not.toContain(marker);
      }
      if (displayPath.startsWith("ritual-investing-api/src/")) {
        expect(source, `${displayPath} uses the Deno runtime`).not.toContain("Deno.");
        expect(
          source,
          `${displayPath} reaches into Supabase Edge adapters`,
        ).not.toMatch(/from\s+["'][^"']*supabase\/functions\//);
      }

      const specifiers = new Set<string>();
      for (const pattern of [
        /\b(?:import|export)\s+(?:type\s+)?(?:[^"']*?\s+from\s+)?["']([^"']+)["']/g,
        /\bimport\(["']([^"']+)["']\)/g,
      ]) {
        for (const match of source.matchAll(pattern)) {
          const specifier = match[1];
          if (specifier !== undefined) specifiers.add(specifier);
        }
      }
      for (const specifier of specifiers) {
        if (!specifier.startsWith(".")) continue;
        const unresolved = resolve(dirname(absolutePath), specifier);
        const candidates = specifier.endsWith(".ts")
          ? [unresolved]
          : [unresolved, `${unresolved}.ts`, resolve(unresolved, "index.ts")];
        const imported = candidates.find((candidate) => existsSync(candidate));
        expect(imported, `${displayPath} has unresolved import ${specifier}`).toBeDefined();
        if (imported !== undefined) await visit(imported);
      }
    };

    for (const path of acceptedEntries) {
      await visit(resolve(repositoryRoot, path));
    }

    expect([...visited].map(repositoryPath)).toEqual(
      expect.arrayContaining(acceptedEntries),
    );
  });
});
