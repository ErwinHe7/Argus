import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { dirname, relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const apiSourceRoot = resolve(repositoryRoot, "ritual-investing-api/src");
const domainSourceRoot = resolve(apiSourceRoot, "domains");
const edgeSourceRoot = resolve(repositoryRoot, "supabase/functions");

const approvedRepositoryCompositionRoots = new Set([
  "supabase/functions/api/index.ts",
  "supabase/functions/webull-callback/index.ts",
  "supabase/functions/worker/index.ts",
]);
const approvedPoolCompositionRoots = new Set([
  ...approvedRepositoryCompositionRoots,
  "supabase/functions/waitlist/index.ts",
]);

type ParsedSource = Readonly<{
  absolutePath: string;
  displayPath: string;
  source: string;
}>;

async function listTypeScriptFiles(root: string): Promise<string[]> {
  const paths: string[] = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = resolve(root, entry.name);
    if (entry.isDirectory()) {
      paths.push(...await listTypeScriptFiles(path));
    } else if (entry.isFile() && entry.name.endsWith(".ts")) {
      paths.push(path);
    }
  }
  return paths.sort();
}

async function parseSource(absolutePath: string): Promise<ParsedSource> {
  const displayPath = relative(repositoryRoot, absolutePath);
  const source = await readFile(absolutePath, "utf8");
  return {
    absolutePath,
    displayPath,
    source,
  };
}

function importedModuleSpecifiers(source: string): string[] {
  const specifiers = new Set<string>();
  for (const pattern of [
    /\b(?:import|export)\s+(?:type\s+)?(?:[^"']*?\s+from\s+)?["']([^"']+)["']/g,
    /\bimport\(\s*["']([^"']+)["']\s*\)/g,
  ]) {
    for (const match of source.matchAll(pattern)) {
      if (match[1] !== undefined) specifiers.add(match[1]);
    }
  }
  return [...specifiers];
}

function resolveLocalImport(
  importer: ParsedSource,
  specifier: string,
): string | undefined {
  if (!specifier.startsWith(".")) return undefined;
  const unresolved = resolve(dirname(importer.absolutePath), specifier);
  const candidates = specifier.endsWith(".ts")
    ? [unresolved]
    : [unresolved, `${unresolved}.ts`, resolve(unresolved, "index.ts")];
  return candidates.find((candidate) => existsSync(candidate));
}

function domainName(path: string): string | undefined {
  return path.match(/ritual-investing-api\/src\/domains\/([^/]+)\//)?.[1];
}

function isConcreteDomainAdapter(path: string): boolean {
  return path.includes("/adapters/") ||
    path.includes("/repositories/") ||
    /\/(?:repository|adapter|supabase-adapter|supabase-repository)\.ts$/.test(path);
}

function calledFactories(source: string, pattern: RegExp): string[] {
  const calls: string[] = [];
  for (const match of source.matchAll(pattern)) {
    const name = match[1];
    if (name === undefined) continue;
    const prefix = source.slice(Math.max(0, match.index - 32), match.index);
    if (/\bfunction\s+$/.test(prefix)) continue;
    calls.push(name);
  }
  return calls;
}

function isTestSource(path: string): boolean {
  return path.includes("/test/") ||
    path.endsWith(".test.ts") ||
    path.endsWith("_test.ts");
}

function queryLiterals(source: string): string[] {
  const literals: string[] = [];
  const query = /\.(?:query|execute)(?:<[^;()]*>)?\s*\(\s*(`(?:\\.|[^`])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/gs;
  for (const match of source.matchAll(query)) {
    const literal = match[1];
    if (literal !== undefined) literals.push(literal.slice(1, -1));
  }
  return literals;
}

function executableSql(text: string): string {
  let sql = text.trimStart();
  while (sql.startsWith("--") || sql.startsWith("/*")) {
    if (sql.startsWith("--")) {
      const newline = sql.indexOf("\n");
      if (newline === -1) return "";
      sql = sql.slice(newline + 1).trimStart();
      continue;
    }
    const end = sql.indexOf("*/", 2);
    if (end === -1) return "";
    sql = sql.slice(end + 2).trimStart();
  }
  return sql;
}

describe("domain and Supabase composition boundaries", () => {
  it("keeps concrete domain adapters inside their owning bounded context", async () => {
    const domainFiles = await Promise.all(
      (await listTypeScriptFiles(domainSourceRoot)).map(parseSource),
    );
    const violations: string[] = [];

    for (const importer of domainFiles) {
      const importerDomain = domainName(importer.displayPath);
      expect(importerDomain, `${importer.displayPath} has no domain owner`).toBeDefined();
      for (const specifier of importedModuleSpecifiers(importer.source)) {
        const importedPath = resolveLocalImport(importer, specifier);
        if (importedPath === undefined) continue;
        const importedDisplayPath = relative(repositoryRoot, importedPath);
        const importedDomain = domainName(importedDisplayPath);
        if (
          importedDomain !== undefined &&
          importedDomain !== importerDomain &&
          isConcreteDomainAdapter(importedDisplayPath)
        ) {
          violations.push(`${importer.displayPath} -> ${importedDisplayPath}`);
        }
        if (importedDisplayPath === "ritual-investing-api/src/db/supabase-repositories.ts") {
          violations.push(`${importer.displayPath} -> retained Supabase adapter`);
        }
      }
    }

    expect(violations).toEqual([]);
  });

  it("keeps route and service policy independent from concrete adapters", async () => {
    const policyFiles = (await listTypeScriptFiles(domainSourceRoot)).filter(
      (path) => /\/(?:routes|service)\.ts$/.test(path),
    );
    const violations: string[] = [];

    for (const importer of await Promise.all(policyFiles.map(parseSource))) {
      for (const specifier of importedModuleSpecifiers(importer.source)) {
        const importedPath = resolveLocalImport(importer, specifier);
        if (importedPath === undefined) continue;
        const importedDisplayPath = relative(repositoryRoot, importedPath);
        if (isConcreteDomainAdapter(importedDisplayPath)) {
          violations.push(`${importer.displayPath} -> ${importedDisplayPath}`);
        }
      }
    }

    expect(violations).toEqual([]);
  });

  it("assembles concrete repositories and database pools only in reviewed roots", async () => {
    const productionFiles = await Promise.all(
      [
        ...await listTypeScriptFiles(apiSourceRoot),
        ...await listTypeScriptFiles(edgeSourceRoot),
      ].filter((path) => !isTestSource(path)).map(parseSource),
    );
    const repositoryCompositions: string[] = [];
    const poolCompositions: string[] = [];
    const violations: string[] = [];

    for (const source of productionFiles) {
      for (
        const name of calledFactories(
          source.source,
          /\b(create(?:Supabase|Brokerage|Webull)[A-Za-z0-9]*Repository)\s*\(/g,
        )
      ) {
        repositoryCompositions.push(`${source.displayPath}:${name}`);
        if (!approvedRepositoryCompositionRoots.has(source.displayPath)) {
          violations.push(`${source.displayPath} assembles ${name}`);
        }
      }
      for (
        const name of calledFactories(
          source.source,
          /\b(createSupabase(?:Worker|Waitlist)?DatabasePool)\s*\(/g,
        )
      ) {
        poolCompositions.push(`${source.displayPath}:${name}`);
        if (!approvedPoolCompositionRoots.has(source.displayPath)) {
          violations.push(`${source.displayPath} assembles ${name}`);
        }
      }
    }

    expect(repositoryCompositions.length).toBeGreaterThan(0);
    expect(poolCompositions.length).toBeGreaterThan(0);
    expect(violations).toEqual([]);
  });

  it("keeps transaction control and connection checkout out of repositories", async () => {
    const repositoryFiles = [
      resolve(apiSourceRoot, "db/supabase-repositories.ts"),
      ...(await listTypeScriptFiles(domainSourceRoot)).filter((path) =>
        isConcreteDomainAdapter(relative(repositoryRoot, path))
      ),
    ];
    const violations: string[] = [];

    for (const source of await Promise.all(repositoryFiles.map(parseSource))) {
      if (/\.connect\s*\(/.test(source.source)) {
        violations.push(`${source.displayPath} checks out a pool connection`);
      }
      for (const literal of queryLiterals(source.source)) {
        const sql = executableSql(literal);
        if (
          literal.includes(";") ||
          /^(?:begin|start\s+transaction|commit|end|abort|rollback|savepoint|release|prepare\s+transaction|set\s+transaction)\b/i.test(
            sql,
          )
        ) {
          violations.push(`${source.displayPath} issues transaction control: ${sql.slice(0, 40)}`);
        }
      }
    }

    expect(violations).toEqual([]);
  });

  it("constructs request repositories from the current transaction executor", async () => {
    const repositoryFiles = (await listTypeScriptFiles(domainSourceRoot)).filter((path) =>
      isConcreteDomainAdapter(relative(repositoryRoot, path))
    );
    const violations: string[] = [];
    const transactionOwners =
      /\b(?:ownerTransaction|legacyOwnerTransaction|editorialStaffTransaction|staffTransaction|capabilityStaffTransaction|activeStaffTransaction|anonymousTransaction|with(?:Active|Anonymous|Callback|Capability|Editorial|Member|Request|Staff|Database)[A-Za-z]*Transaction)\b/;

    for (const source of await Promise.all(repositoryFiles.map(parseSource))) {
      const reasons: string[] = [];
      if (/\b(?:DatabasePool|SupabaseRepositoryBinding)\b/.test(source.source)) {
        reasons.push("owns a pool/request binding");
      }
      if (transactionOwners.test(source.source)) {
        reasons.push("opens its own transaction");
      }
      if (!/\b(?:DatabaseTransaction|RequestDatabase)\b/.test(source.source)) {
        reasons.push("does not accept a transaction executor");
      }
      if (reasons.length > 0) {
        violations.push(`${source.displayPath}: ${reasons.join(", ")}`);
      }
    }

    expect(violations).toEqual([]);
  });

  it("keeps retained compatibility files free of SQL and domain implementation", async () => {
    const repositories = await parseSource(
      resolve(apiSourceRoot, "db/supabase-repositories.ts"),
    );
    const retainedApp = await parseSource(resolve(apiSourceRoot, "retained-app.ts"));
    const repositoryImplementationStatements = repositories.source.split("\n")
      .map((line) => line.trim())
      .filter((line) =>
        /^import\b/.test(line) ||
        (
          /^(?:export\s+)?(?:async\s+)?(?:function|class|const|let|var|interface|type)\b/.test(
            line,
          ) &&
          !/^export\s+type\s+\{/.test(line)
        )
      );
    const retainedSql = queryLiterals(retainedApp.source)
      .map(executableSql)
      .filter((sql) => /^(?:select|insert|update|delete|merge|with|call|do)\b/i.test(sql));
    const retainedAdapterImports = importedModuleSpecifiers(retainedApp.source)
      .map((specifier) => resolveLocalImport(retainedApp, specifier))
      .filter((path): path is string => path !== undefined)
      .map((path) => relative(repositoryRoot, path))
      .filter((path) =>
        path === "ritual-investing-api/src/db/supabase-repositories.ts" ||
        isConcreteDomainAdapter(path)
      );
    const retainedDomainImplementation: string[] = [];
    if (/\bcreateRoute\s*\(/.test(retainedApp.source)) {
      retainedDomainImplementation.push("creates a route contract directly");
    }
    if (/\.openapi\s*\(/.test(retainedApp.source)) {
      retainedDomainImplementation.push("registers a domain route directly");
    }
    if (
      /\bz\.(?:array|boolean|enum|literal|number|object|record|string|union)\s*\(/.test(
        retainedApp.source,
      )
    ) {
      retainedDomainImplementation.push("declares a domain schema directly");
    }

    expect(
      repositoryImplementationStatements.map((statement) => statement.trim()),
      "the retained repository module must contain re-exports only",
    ).toEqual([]);
    expect(retainedSql, "the retained app must not contain SQL").toEqual([]);
    expect(
      retainedAdapterImports,
      "the portable retained app must depend on domain ports, not concrete adapters",
    ).toEqual([]);
    expect(retainedDomainImplementation).toEqual([]);
  });

  it("keeps content projections free of recursive JSON discovery and fabricated defaults", async () => {
    const contentService = await parseSource(
      resolve(domainSourceRoot, "content/service.ts"),
    );
    expect(contentService.source).not.toMatch(/\bconst\s+visit\s*=/);
    expect(contentService.source).not.toContain("matchesPublishedSearch");
    expect(contentService.source).not.toContain("EPOCH_ISO");
    expect(contentService.source).not.toMatch(
      /unavailable|Unknown publisher|Argus editor\b|Published qualification|My circle/,
    );
  });
});
