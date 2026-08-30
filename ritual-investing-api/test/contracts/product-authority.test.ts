import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";
import YAML from "yaml";

import { retainedJobHandlers } from "../../src/jobs/scheduled.ts";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const readRepo = (path: string) => readFileSync(join(repoRoot, path), "utf8");

const productPaths = [
  "ritual-investing-app/PRODUCT.md",
  "ritual-investing-app/README.md",
  "ritual-investing-site/PRODUCT.md",
  "docs/solutions/architecture-patterns/ritual-investing-app-current-intent-and-architecture.md",
] as const;

type Classification =
  | "retained-argus"
  | "replaced-webull"
  | "standalone-demo-only"
  | "deleted";

const classifications = new Set<Classification>([
  "retained-argus",
  "replaced-webull",
  "standalone-demo-only",
  "deleted",
]);

type InventoryEntry = {
  surface: string;
  classification: Classification;
  owner: string;
};

function inventoryEntries(): InventoryEntry[] {
  const inventory = readRepo("docs/ritual-investing/member-data-inventory.md");
  const block = inventory.match(
    /<!-- authority-inventory:start -->([\s\S]*?)<!-- authority-inventory:end -->/,
  )?.[1];
  expect(block, "machine-checkable authority inventory block").toBeDefined();

  return [...block!.matchAll(/^\| `([^`]+)` \| ([a-z-]+) \| ([^|]+) \|/gm)].map(
    ([, surface, classification, owner]) => {
      if (surface === undefined || classification === undefined || owner === undefined) {
        throw new Error("invalid_authority_inventory_row");
      }
      expect(classifications.has(classification as Classification), surface).toBe(true);
      return {
        surface,
        classification: classification as Classification,
        owner: owner.trim(),
      };
    },
  );
}

function expectExactlyOnce(actual: string[], expected: string[], label: string) {
  const counts = new Map<string, number>();
  for (const item of actual) counts.set(item, (counts.get(item) ?? 0) + 1);
  expect(
    [...counts.entries()].filter(([, count]) => count !== 1),
    `${label} duplicated in the authority inventory`,
  ).toEqual([]);
  expect([...counts.keys()].sort(), `${label} coverage`).toEqual([...expected].sort());
}

function currentTables(): string[] {
  const migrations = readdirSync(join(repoRoot, "supabase/migrations"))
    .filter((path) => path.endsWith(".sql"))
    .map((path) => readRepo(`supabase/migrations/${path}`))
    .join("\n");
  return [...migrations.matchAll(/create table(?: if not exists)?\s+([\w.\"]+)/gi)]
    .map((match) => match[1]!.replaceAll('"', "").split(".").at(-1)!)
    .filter((table, index, all) => all.indexOf(table) === index);
}

function currentApiDomains(): string[] {
  return readdirSync(join(repoRoot, "ritual-investing-api/src/domains"), {
    withFileTypes: true,
  })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name);
}

function currentQueueConsumers(): string[] {
  return [...new Set(Object.values(retainedJobHandlers))];
}

function currentRoutes(): string[] {
  const document = YAML.parse(
    readRepo("ritual-investing-api/openapi/ritual-investing-v1.yaml"),
  ) as { paths: Record<string, unknown> };
  return Object.keys(document.paths);
}

describe("product authority contract", () => {
  it("keeps Starpath factual learning separate from release-control and financial authority", () => {
    const entries = inventoryEntries();
    const starpath = entries.find(({ surface }) =>
      surface === "api-domain:starpath"
    );
    expect(starpath).toMatchObject({ classification: "retained-argus" });
    expect(starpath?.owner).toContain("Factual investment-literacy");

    const repository = readRepo(
      "ritual-investing-api/src/domains/starpath/repository.ts",
    );
    const ports = readRepo("ritual-investing-api/src/domains/starpath/ports.ts");
    const memberProjection = readRepo(
      "supabase/migrations/20260830071000_starpath_member_api.sql",
    );
    expect(ports).toContain("External RC1 consumer boundary");
    expect(repository).toContain(
      "argus_private.resolve_starpath_member_authority",
    );
    expect(repository).toContain(
      "argus_private.read_starpath_curriculum_projection",
    );
    expect(repository).not.toMatch(
      /argus_app\.(?:profiles|astrology_profiles|investor_profiles)|argus_brokerage/,
    );
    expect(memberProjection).not.toMatch(
      /'isCorrect'\s*,\s*option_record\.is_correct/,
    );
  });

  it("states one Webull, Argus, Supabase, Demo, and Pages authority model", () => {
    const combined = productPaths.map(readRepo).join("\n");

    expect(combined).toContain("Webull is authoritative for brokerage accounts");
    expect(combined).toContain("Argus is authoritative for ritual, editorial, community, preference, and privacy state");
    expect(combined).toContain("Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage");
    expect(combined).toContain("The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated");
    expect(combined).toContain("Cloudflare Pages serves only static landing and standalone Demo assets");
    expect(combined).toContain("Rowan cannot issue financial commands");

    expect(readRepo("ritual-investing-app/PRODUCT.md")).not.toContain(
      "complete simulated investing journey",
    );
    expect(readRepo("ritual-investing-app/README.md")).not.toContain(
      "Provider-free Demo portfolio",
    );
  });

  it("classifies every current Supabase table, API domain, and queue handler without reviving deleted authority", () => {
    const entries = inventoryEntries();
    const tableEntries = entries.filter(({ surface }) =>
      surface.startsWith("database-table:")
    );
    const currentTableSet = new Set(currentTables());
    for (const table of currentTableSet) {
      expect(
        tableEntries.filter(({ surface, classification }) =>
          surface === `database-table:${table}` && classification !== "deleted"
        ),
        `${table} must have one live authority entry`,
      ).toHaveLength(1);
    }
    for (const { surface, classification } of tableEntries) {
      if (classification === "deleted") {
        expect(currentTableSet, `${surface} must be absent from Supabase`).not.toContain(
          surface.slice("database-table:".length),
        );
      }
    }

    const currentDomainSet = new Set(currentApiDomains());
    const domainEntries = entries.filter(({ surface }) =>
      surface.startsWith("api-domain:")
    );
    for (const domain of currentDomainSet) {
      expect(
        domainEntries.filter(({ surface, classification }) =>
          surface === `api-domain:${domain}` && classification !== "deleted"
        ),
        `${domain} must have one live authority entry`,
      ).toHaveLength(1);
    }
    for (const { surface, classification } of domainEntries) {
      if (classification === "deleted") {
        expect(currentDomainSet, `${surface} must be absent from the API`).not.toContain(
          surface.slice("api-domain:".length),
        );
      }
    }
    for (const handler of currentQueueConsumers()) {
      expect(
        entries.filter(({ surface }) => surface === `background-handler:${handler}`),
        `${handler} must have one authority entry`,
      ).toHaveLength(1);
    }
    expect(currentQueueConsumers()).not.toContain("recurring-plan-delivery");
  });

  it("classifies every generated API route through one non-overlapping rule", () => {
    const rules = inventoryEntries()
      .filter(({ surface }) => surface.startsWith("api-route-pattern:"))
      .map(({ surface, classification }) => ({
        pattern: new RegExp(surface.slice("api-route-pattern:".length)),
        classification,
      }));
    expect(rules.length).toBeGreaterThan(0);

    for (const route of currentRoutes()) {
      const matches = rules.filter(({ pattern }) => pattern.test(route));
      expect(matches, `${route} must have exactly one authority rule`).toHaveLength(1);
    }
  });

  it("preserves the standalone Demo and Rowan boundaries while deleting live simulation authority", () => {
    const entries = inventoryEntries();
    const bySurface = new Map(entries.map((entry) => [entry.surface, entry]));

    expect(bySurface.get("client:standalone-demo")?.classification).toBe(
      "standalone-demo-only",
    );
    expect(bySurface.get("client:rowan")?.classification).toBe("retained-argus");
    expect(bySurface.get("live-financial-feature:funding")?.classification).toBe(
      "deleted",
    );
    expect(bySurface.get("live-financial-feature:recurring-execution")?.classification)
      .toBe("deleted");
    expect(bySurface.get("live-financial-feature:rebalance-execution")?.classification)
      .toBe("deleted");
    expect(bySurface.get("live-financial-feature:brokerage-reads")?.classification)
      .toBe("replaced-webull");
    expect(bySurface.get("live-financial-feature:manual-orders")?.classification)
      .toBe("replaced-webull");
    expect(bySurface.get("client:rowan")?.owner).toContain("no brokerage prompt context");
  });

  it("records replacement-first provider and operations ownership", () => {
    const entries = inventoryEntries();
    const classificationFor = (surface: string) =>
      entries.find((entry) => entry.surface === surface)?.classification;

    for (const provider of [
      "auth0",
      "neon",
      "cloudflare-queues",
      "r2",
      "cloudflare-access",
      "drizzle",
    ]) {
      expect(classificationFor(`provider-dependency:${provider}`), provider).toBe("deleted");
    }
    expect(classificationFor("provider-dependency:webull-connect")).toBe(
      "replaced-webull",
    );
    expect(classificationFor("provider-dependency:supabase")).toBe("retained-argus");
    expect(classificationFor("provider-dependency:cloudflare-workers")).toBe(
      "retained-argus",
    );

    const requiredOperationTypes = [
      "storage-object:",
      "secret-family:",
      "runbook:",
      "client:member-",
      "client:admin-",
      "site-endpoint:",
    ];
    for (const prefix of requiredOperationTypes) {
      expect(entries.some(({ surface }) => surface.startsWith(prefix)), prefix).toBe(true);
    }
  });

  it("keeps the historical DriveWealth and Plaid plan outside current authority sources", () => {
    const sourceDocuments = productPaths.map(readRepo).join("\n") +
      readRepo("docs/ritual-investing/member-data-inventory.md");
    expect(sourceDocuments).not.toContain(
      "docs/plans/2026-08-26-0121-feat-drivewealth-plaid-backend-plan.md",
    );
  });
});
