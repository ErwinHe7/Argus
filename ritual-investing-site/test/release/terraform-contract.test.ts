import { readdir, readFile, stat } from "node:fs/promises";
import { relative, resolve } from "node:path";
import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const terraformRoot = resolve(repositoryRoot, "infra/terraform/ritual-investing");

const requiredFiles = [
  "README.md",
  "backends/staging.hcl",
  "backends/prod.hcl",
  "modules/pages-environment/main.tf",
  "modules/pages-environment/variables.tf",
  "modules/pages-environment/outputs.tf",
  ...["staging", "prod"].flatMap((environment) => [
    `environments/${environment}/backend.tf`,
    `environments/${environment}/main.tf`,
    `environments/${environment}/outputs.tf`,
    `environments/${environment}/providers.tf`,
    `environments/${environment}/variables.tf`,
    `environments/${environment}/.terraform.lock.hcl`,
  ]),
];

async function filesUnder(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    const path = resolve(directory, entry.name);
    return entry.isDirectory() ? filesUnder(path) : [path];
  }));
  return files.flat();
}

async function text(path: string): Promise<string> {
  return readFile(resolve(terraformRoot, path), "utf8");
}

function stringValue(source: string, name: string): string {
  const match = new RegExp(`\\b${name}\\s*=\\s*"([^"]+)"`).exec(source);
  const value = match?.[1];
  if (value === undefined) throw new Error(`Missing string value: ${name}`);
  return value;
}

function resourceBlocks(source: string): Array<{ type: string; body: string }> {
  const startPattern = /resource\s+"([^"]+)"\s+"[^"]+"\s*\{/g;
  const blocks: Array<{ type: string; body: string }> = [];
  let match: RegExpExecArray | null;

  while ((match = startPattern.exec(source)) !== null) {
    let depth = 1;
    let cursor = startPattern.lastIndex;
    while (cursor < source.length && depth > 0) {
      if (source[cursor] === "{") depth += 1;
      if (source[cursor] === "}") depth -= 1;
      cursor += 1;
    }
    const type = match[1];
    if (type === undefined) throw new Error("Terraform resource type is missing");
    if (depth !== 0) throw new Error(`Unclosed Terraform resource: ${type}`);
    blocks.push({ type, body: source.slice(match.index, cursor) });
    startPattern.lastIndex = cursor;
  }

  return blocks;
}

type PlanSummary = {
  resource_changes?: Array<{ change?: { actions?: string[] } }>;
};

function acceptsPlanSummary(summary: PlanSummary): boolean {
  return (summary.resource_changes ?? []).every(({ change }) => {
    const actions = change?.actions ?? [];
    return actions.length > 0 && !actions.includes("delete");
  });
}

describe("Ritual Terraform release contract", () => {
  it("has only separate staging and prod roots with committed provider locks", async () => {
    const environments = (await readdir(resolve(terraformRoot, "environments"), {
      withFileTypes: true,
    }))
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();

    expect(environments).toEqual(["prod", "staging"]);
    await Promise.all(requiredFiles.map(async (path) => expect((await stat(
      resolve(terraformRoot, path),
    )).isFile()).toBe(true)));

    for (const environment of environments) {
      const lock = await text(`environments/${environment}/.terraform.lock.hcl`);
      expect(lock).toContain('provider "registry.terraform.io/cloudflare/cloudflare"');
      expect(lock).toContain('version     = "5.24.0"');
      expect(lock).toContain('provider "registry.terraform.io/integrations/github"');
      expect(lock).toContain('version     = "6.13.0"');
      expect(lock).toMatch(/hashes\s*=\s*\[\s*"(?:h1|zh):/);
    }
  });

  it("pins Terraform and providers narrowly in both roots", async () => {
    for (const environment of ["staging", "prod"]) {
      const providers = await text(`environments/${environment}/providers.tf`);
      expect(providers).toMatch(/required_version\s*=\s*"~> 1\.15\.0"/);
      expect(providers).toMatch(/cloudflare[\s\S]*?version\s*=\s*"~> 5\.24\.0"/);
      expect(providers).toMatch(/github[\s\S]*?version\s*=\s*"~> 6\.13\.0"/);
    }
  });

  it("uses distinct lock-protected R2 buckets and keys without CLI workspaces", async () => {
    const [staging, prod] = await Promise.all([
      text("backends/staging.hcl"),
      text("backends/prod.hcl"),
    ]);

    expect(new Set([stringValue(staging, "bucket"), stringValue(prod, "bucket")]).size).toBe(2);
    expect(new Set([stringValue(staging, "key"), stringValue(prod, "key")]).size).toBe(2);
    for (const backend of [staging, prod]) {
      expect(backend).toMatch(/\buse_lockfile\s*=\s*true\b/);
      expect(backend).toMatch(/\bencrypt\s*=\s*true\b/);
      expect(backend).not.toMatch(/\bworkspace_key_prefix\b|\bworkspaces?\s*=/i);
    }

    const terraformFiles = (await filesUnder(terraformRoot)).filter((path) =>
      /\.(?:tf|hcl)$/.test(path) && !path.endsWith(".terraform.lock.hcl")
    );
    const terraform = (await Promise.all(terraformFiles.map((path) => readFile(path, "utf8"))))
      .join("\n");
    expect(terraform).not.toMatch(/\bterraform\s+workspace\b/i);
  });

  it("allows only stable nonsecret control-plane resources", async () => {
    const configurationFiles = (await filesUnder(terraformRoot)).filter((path) =>
      path.endsWith(".tf") || (path.endsWith(".hcl") && !path.endsWith(".terraform.lock.hcl"))
    );
    const configuration = (await Promise.all(
      configurationFiles.map((path) => readFile(path, "utf8")),
    )).join("\n");
    const allowedResources = new Set([
      "cloudflare_pages_project",
      "cloudflare_pages_domain",
      "cloudflare_dns_record",
      "github_repository_environment",
      "github_actions_environment_variable",
    ]);

    const blocks = resourceBlocks(configuration);
    expect(blocks.length).toBeGreaterThanOrEqual(5);
    expect(blocks.every(({ type }) => allowedResources.has(type))).toBe(true);
    expect(configuration).not.toMatch(
      /\b(?:api_token|token|password|client_secret|access_key|secret_key|credentials?)\s*=/i,
    );
    expect(configuration).not.toMatch(
      /github_actions_environment_secret|cloudflare_pages_deployment|wrangler|supabase|workers?_script/i,
    );
  });

  it("protects every prod-owned resource from destroy", async () => {
    const [moduleMain, prodMain] = await Promise.all([
      text("modules/pages-environment/main.tf"),
      text("environments/prod/main.tf"),
    ]);
    expect(prodMain).toMatch(/module\s+"pages_environment"/);

    const blocks = resourceBlocks(moduleMain);
    expect(blocks.map(({ type }) => type).sort()).toEqual([
      "cloudflare_dns_record",
      "cloudflare_pages_domain",
      "cloudflare_pages_project",
      "github_actions_environment_variable",
      "github_repository_environment",
    ]);
    for (const { body } of blocks) {
      expect(body).toMatch(/lifecycle\s*\{[\s\S]*?prevent_destroy\s*=\s*true/);
    }
  });

  it("rejects cross-environment names at root and module boundaries", async () => {
    const [staging, prod, moduleVariables] = await Promise.all([
      text("environments/staging/variables.tf"),
      text("environments/prod/variables.tf"),
      text("modules/pages-environment/variables.tf"),
    ]);

    expect(staging).toContain('var.environment == "staging"');
    expect(staging).toMatch(/pages_project_name[\s\S]*staging[\s\S]*prod/i);
    expect(staging).toMatch(/pages_domain[\s\S]*staging[\s\S]*prod/i);
    expect(prod).toContain('var.environment == "prod"');
    expect(prod).toMatch(/pages_project_name[\s\S]*prod[\s\S]*staging/i);
    expect(prod).toMatch(/pages_domain[\s\S]*prod[\s\S]*staging/i);
    expect(moduleVariables).toMatch(/contains\(\["staging", "prod"\], var\.environment\)/);
    expect(moduleVariables).toMatch(/opposite environment/i);
  });

  it("keeps local state and saved plans ignored while allowing provider locks", async () => {
    const allPaths = (await filesUnder(terraformRoot)).map((path) => relative(terraformRoot, path));
    expect(allPaths).not.toContain("environments/staging/terraform.tfstate");
    expect(allPaths).not.toContain("environments/prod/terraform.tfstate");
    expect(allPaths.every((path) => !/(?:\.tfstate(?:\.|$)|\.tfplan(?:\.|$)|\.plan$)/.test(path)))
      .toBe(true);

    const gitignore = await readFile(resolve(repositoryRoot, ".gitignore"), "utf8");
    expect(gitignore).toMatch(/infra\/terraform\/\*\*\/\.terraform\//);
    expect(gitignore).toMatch(/infra\/terraform\/\*\*\/\*\.tfstate/);
    expect(gitignore).toMatch(/infra\/terraform\/\*\*\/\*\.tfplan/);
    expect(gitignore).toContain("!infra/terraform/**/.terraform.lock.hcl");
  });

  it("documents mandatory live state proof and fails closed to state-only HCP", async () => {
    const readme = await text("README.md");
    for (const phrase of [
      "versioning",
      "encryption at rest",
      "separate principals",
      "two-client lock",
      "cross-environment access denial",
      "version recovery",
      "retention",
      "HCP Terraform",
      "state-only",
      "local execution",
      "stop",
    ]) expect(readme.toLowerCase()).toContain(phrase.toLowerCase());
    expect(readme).toMatch(/outside this\s+Terraform\s+stack/i);
    expect(readme).toMatch(/staging[\s\S]*prod[\s\S]*bucket/i);
    expect(readme).toMatch(/wrangler[\s\S]*excluded/i);
    expect(readme).toMatch(/supabase[\s\S]*excluded/i);
  });

  it("rejects a mocked destructive or replacement plan summary before apply", async () => {
    expect(acceptsPlanSummary({
      resource_changes: [{ change: { actions: ["update"] } }],
    })).toBe(true);
    expect(acceptsPlanSummary({
      resource_changes: [{ change: { actions: ["delete"] } }],
    })).toBe(false);
    expect(acceptsPlanSummary({
      resource_changes: [{ change: { actions: ["delete", "create"] } }],
    })).toBe(false);

    const readme = await text("README.md");
    expect(readme).toContain("terraform show -json");
    expect(readme).toMatch(/delete or replacement[\s\S]*stop/i);
  });
});
