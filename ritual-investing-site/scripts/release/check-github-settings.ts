import { pathToFileURL } from "node:url";

type EnvironmentName = "staging" | "prod";

export type GitHubSettingsOptions = {
  repository: string;
  token?: string;
  fetchImpl?: typeof fetch;
  now?: () => Date;
};

type EnvironmentEvidence = {
  reviewers: number;
  waitTimerMinutes: number;
  deploymentBranchPolicy: boolean;
};

export type GitHubSettingsReceipt = {
  schemaVersion: 1;
  checkedAt: string;
  repository: string;
  passed: boolean;
  branches: { count: number; protected: string[] };
  main: { protection: boolean; requiredChecks: string[] };
  rulesets: { count: number };
  environments: Record<EnvironmentName, EnvironmentEvidence>;
  violations: string[];
};

const REPOSITORY = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const API_ROOT = "https://api.github.com";
const ENVIRONMENTS: EnvironmentName[] = ["staging", "prod"];

function object(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} response is invalid`);
  }
  return value as Record<string, unknown>;
}

async function json(response: Response, label: string): Promise<unknown> {
  if (!response.ok) throw new Error(`${label} request failed with HTTP ${response.status}`);
  return response.json() as Promise<unknown>;
}

async function paginated(
  request: (path: string) => Promise<Response>,
  path: string,
  label: string,
): Promise<unknown[]> {
  const records: unknown[] = [];
  for (let page = 1; page <= 100; page += 1) {
    const separator = path.includes("?") ? "&" : "?";
    const payload = await json(await request(`${path}${separator}per_page=100&page=${page}`), label);
    if (!Array.isArray(payload)) throw new Error(`${label} response is invalid`);
    records.push(...payload);
    if (payload.length < 100) return records;
  }
  throw new Error(`${label} pagination exceeded the safety limit`);
}

function environmentEvidence(payload: unknown, environment: EnvironmentName): {
  evidence: EnvironmentEvidence;
  unknownProtectionRules: number;
} {
  const record = object(payload, `${environment} environment`);
  const protectionRules = record.protection_rules;
  if (!Array.isArray(protectionRules)) {
    throw new Error(`${environment} environment protection rules are invalid`);
  }

  let reviewers = 0;
  let waitTimerMinutes = 0;
  let unknownProtectionRules = 0;
  for (const value of protectionRules) {
    const rule = object(value, `${environment} environment protection rule`);
    if (rule.type === "required_reviewers") {
      if (!Array.isArray(rule.reviewers)) {
        throw new Error(`${environment} environment reviewers are invalid`);
      }
      reviewers += rule.reviewers.length;
    } else if (rule.type === "wait_timer") {
      if (!Number.isInteger(rule.wait_timer) || (rule.wait_timer as number) < 0) {
        throw new Error(`${environment} environment wait timer is invalid`);
      }
      waitTimerMinutes = Math.max(waitTimerMinutes, rule.wait_timer as number);
    } else {
      unknownProtectionRules += 1;
    }
  }

  return {
    evidence: {
      reviewers,
      waitTimerMinutes,
      deploymentBranchPolicy: record.deployment_branch_policy !== null,
    },
    unknownProtectionRules,
  };
}

export async function checkGitHubSettings(
  options: GitHubSettingsOptions,
): Promise<GitHubSettingsReceipt> {
  if (!REPOSITORY.test(options.repository)) {
    throw new Error("GitHub repository must be an exact owner/name slug");
  }
  const fetchImpl = options.fetchImpl ?? fetch;
  const headers = new Headers({
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  });
  if (options.token !== undefined && options.token !== "") {
    headers.set("Authorization", `Bearer ${options.token}`);
  }
  const request = async (path: string): Promise<Response> => fetchImpl(
    `${API_ROOT}/repos/${options.repository}${path}`,
    { method: "GET", headers, redirect: "error" },
  );

  const [branches, rulesets, mainProtection, requiredChecks, ...environmentResponses] =
    await Promise.all([
      paginated(request, "/branches", "Repository branches"),
      paginated(request, "/rulesets?includes_parents=true", "Repository rulesets"),
      request("/branches/main/protection"),
      request("/branches/main/protection/required_status_checks"),
      ...ENVIRONMENTS.map((environment) => request(`/environments/${environment}`)),
    ]);

  const protectedBranches: string[] = [];
  for (const branch of branches) {
    const record = object(branch, "Repository branch");
    if (typeof record.name !== "string" || typeof record.protected !== "boolean") {
      throw new Error("Repository branch response is invalid");
    }
    if (record.protected) protectedBranches.push(record.name);
  }
  protectedBranches.sort();

  if (mainProtection.status !== 404 && !mainProtection.ok) {
    throw new Error(`Main branch protection request failed with HTTP ${mainProtection.status}`);
  }
  const hasMainProtection = mainProtection.ok;

  let requiredCheckNames: string[] = [];
  if (requiredChecks.status !== 404) {
    const required = object(await json(requiredChecks, "Required status checks"), "Required status checks");
    const contexts = Array.isArray(required.contexts) ? required.contexts : [];
    const checks = Array.isArray(required.checks) ? required.checks : [];
    requiredCheckNames = [
      ...contexts.map((value) => {
        if (typeof value !== "string") throw new Error("Required status check context is invalid");
        return value;
      }),
      ...checks.map((value) => {
        const check = object(value, "Required status check");
        if (typeof check.context !== "string") throw new Error("Required status check is invalid");
        return check.context;
      }),
    ].filter((value, index, values) => values.indexOf(value) === index).sort();
  }

  const environmentEntries = await Promise.all(ENVIRONMENTS.map(async (environment, index) => {
    const response = environmentResponses[index];
    if (response === undefined) throw new Error(`${environment} environment response is missing`);
    if (response.status === 404) throw new Error(`${environment} GitHub environment does not exist`);
    const parsed = environmentEvidence(await json(response, `${environment} environment`), environment);
    return [environment, parsed] as const;
  }));
  const environments = Object.fromEntries(environmentEntries.map(([name, value]) => [
    name,
    value.evidence,
  ])) as Record<EnvironmentName, EnvironmentEvidence>;

  const violations: string[] = [];
  if (protectedBranches.length > 0) violations.push("protected branches exist");
  if (hasMainProtection) violations.push("main branch protection exists");
  if (requiredCheckNames.length > 0) violations.push("required status checks exist");
  if (rulesets.length > 0) violations.push("repository rulesets exist");
  for (const [environment, { evidence, unknownProtectionRules }] of environmentEntries) {
    if (evidence.reviewers > 0) violations.push(`${environment} environment reviewers exist`);
    if (evidence.waitTimerMinutes > 0) violations.push(`${environment} environment wait timer exists`);
    if (evidence.deploymentBranchPolicy) {
      violations.push(`${environment} environment deployment branch policy exists`);
    }
    if (unknownProtectionRules > 0) {
      violations.push(`${environment} environment has unknown protection rules`);
    }
  }

  return {
    schemaVersion: 1,
    checkedAt: (options.now ?? (() => new Date()))().toISOString(),
    repository: options.repository,
    passed: violations.length === 0,
    branches: { count: branches.length, protected: protectedBranches },
    main: { protection: hasMainProtection, requiredChecks: requiredCheckNames },
    rulesets: { count: rulesets.length },
    environments,
    violations,
  };
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const receipt = await checkGitHubSettings({
      repository: process.env.GITHUB_REPOSITORY ?? "",
      token: process.env.GITHUB_TOKEN,
    });
    process.stdout.write(`${JSON.stringify(receipt, null, 2)}\n`);
    if (!receipt.passed) {
      console.error("GitHub settings policy check failed");
      process.exitCode = 1;
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : "GitHub settings check failed");
    process.exitCode = 1;
  }
}
