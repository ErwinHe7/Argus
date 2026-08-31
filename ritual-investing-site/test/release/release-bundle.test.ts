import { readFile, writeFile, mkdir } from "node:fs/promises";
import { execFile } from "node:child_process";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { mkdtemp } from "node:fs/promises";
import { promisify } from "node:util";
import { describe, expect, it } from "vitest";

import {
  buildReleaseBundle,
  type ReleaseBuildOptions,
} from "../../scripts/release/build-release-bundle.ts";
import {
  parseReleaseProfile,
  profileReleaseEligibility,
  verifyReleaseBundle,
} from "../../scripts/release/verify-release-bundle.ts";
import { probePagesDeployment } from "../../scripts/release/probe-pages-deployment.ts";

const SHA = "a".repeat(40);
const CONTROLLER_SHA = "b".repeat(40);
const DIGEST = "c".repeat(64);
const STAGING_REF = "zbgjjufjkhfhirbuuolv";
const STAGING_BACKEND_FINGERPRINT =
  "0cad737319cba650c0c5778802f02541f298886ab2c35338edf3c317e149568e";
const execFileAsync = promisify(execFile);

function stagingProfile(): Record<string, unknown> {
  return {
    schemaVersion: 1,
    identity: "ritual-release-staging-v1",
    environment: "staging",
    targets: {
      landing: {
        pagesProject: "ritual-investing-site-staging",
        host: "staging.just-build-this.app",
        backendDependency: {
          classification: "compatible-with",
          requiredFingerprint: STAGING_BACKEND_FINGERPRINT,
          target: {
            status: "approved",
            supabaseProjectRef: STAGING_REF,
            waitlistUrl: `https://${STAGING_REF}.supabase.co/functions/v1/waitlist`,
          },
        },
      },
      demo: {
        pagesProject: "ritual-investing-demo-staging",
        host: "demo-staging.just-build-this.app",
        backendDependency: {
          classification: "backend-independent",
          requiredFingerprint: null,
          target: { status: "not-applicable" },
        },
      },
    },
  };
}

function prodProfile(): Record<string, unknown> {
  return {
    schemaVersion: 1,
    identity: "ritual-release-prod-v1-withheld",
    environment: "prod",
    targets: {
      landing: {
        pagesProject: "ritual-investing-member",
        host: "just-build-this.app",
        backendDependency: {
          classification: "requires",
          requiredFingerprint: null,
          target: {
            status: "withheld",
            reason: "approved-prod-target-not-configured",
          },
        },
      },
      demo: {
        pagesProject: "ritual-investing-demo",
        host: "demo.just-build-this.app",
        backendDependency: {
          classification: "backend-independent",
          requiredFingerprint: null,
          target: { status: "not-applicable" },
        },
      },
    },
  };
}

async function fixture(): Promise<ReleaseBuildOptions> {
  const repositoryRoot = await mkdtemp(join(tmpdir(), "ritual-release-contract-"));
  const packageRoot = join(repositoryRoot, "ritual-investing-site");
  const outputDirectory = join(repositoryRoot, "out-a");

  await Promise.all([
    mkdir(join(packageRoot, "config/release"), { recursive: true }),
    ...["staging", "prod"].flatMap((environment) =>
      ["landing", "demo"].map((surface) =>
        mkdir(join(packageRoot, `dist/${surface}-${environment}`), { recursive: true }),
      )
    ),
    mkdir(join(repositoryRoot, "infra/terraform/ritual-investing/environments/staging"), { recursive: true }),
    mkdir(join(repositoryRoot, "supabase/migrations"), { recursive: true }),
    mkdir(join(repositoryRoot, "supabase/functions/waitlist"), { recursive: true }),
    mkdir(join(repositoryRoot, "docs/ritual-investing"), { recursive: true }),
  ]);
  await Promise.all([
    writeFile(join(packageRoot, "config/release/staging.json"), `${JSON.stringify(stagingProfile(), null, 2)}\n`),
    writeFile(join(packageRoot, "config/release/prod.json"), `${JSON.stringify(prodProfile(), null, 2)}\n`),
    ...["staging", "prod"].flatMap((environment) =>
      ["landing", "demo"].map((surface) =>
        writeFile(join(packageRoot, `dist/${surface}-${environment}/index.html`), `${surface}-${environment}\n`),
      )
    ),
    writeFile(join(repositoryRoot, "infra/terraform/ritual-investing/environments/staging/main.tf"), "terraform {}\n"),
    writeFile(join(repositoryRoot, "supabase/migrations/20260830_release.sql"), "select 1;\n"),
    writeFile(join(repositoryRoot, "supabase/functions/waitlist/index.ts"), "export default {};\n"),
    writeFile(join(repositoryRoot, "docs/ritual-investing/member-data-inventory.md"), "# Inventory\n"),
    writeFile(join(repositoryRoot, "docs/ritual-investing/supabase-migration-inventory-v1.txt"), "contract_version: 1\n"),
    writeFile(join(repositoryRoot, "docs/ritual-investing/supabase-boundary-manifest-v1.txt"), "contract_version: 1\n"),
  ]);

  return {
    repositoryRoot,
    packageRoot,
    outputDirectory,
    sourceDateEpoch: 1_788_134_400,
    provenance: {
      subject: { repository: "owner/argus", sha: SHA, runId: "101", attempt: 1 },
      controller: {
        workflow: "ritual-release.yml",
        ref: "refs/heads/main",
        sha: CONTROLLER_SHA,
        runId: "202",
        attempt: 2,
      },
    },
    toolVersions: {
      node: "22.22.0",
      assetBuilder: "ritual-build-assets-v1",
      archive: "ustar-v1",
      terraform: "1.15.0",
      wrangler: "4.125.0",
      supabase: "2.115.0",
    },
    buildAssets: async () => undefined,
  };
}

describe("immutable Ritual release bundle", () => {
  it("produces identical archive bytes and separately checksummed trees from fixed inputs", async () => {
    const options = await fixture();
    const first = await buildReleaseBundle(options);
    const second = await buildReleaseBundle({
      ...options,
      outputDirectory: join(options.repositoryRoot, "out-b"),
    });

    expect(await readFile(first.archivePath)).toEqual(await readFile(second.archivePath));
    expect(first.archiveSha256).toBe(second.archiveSha256);
    expect(first.manifestSha256).toBe(second.manifestSha256);
    expect(first.manifest.trees.map(({ environment, sha256 }) => ({ environment, sha256 })))
      .toEqual(second.manifest.trees.map(({ environment, sha256 }) => ({ environment, sha256 })));
    expect(first.manifest.trees.map(({ environment }) => environment)).toEqual(["staging", "prod"]);
    expect(first.manifest.files.map(({ path }) => path)).toEqual(
      [...first.manifest.files.map(({ path }) => path)].sort(),
    );
    const listed = (await execFileAsync("tar", ["-tf", first.archivePath])).stdout;
    expect(listed).toContain("release-bundle/release-manifest.json");
    expect(listed).toContain("release-bundle/snapshots/infra/terraform/ritual-investing/environments/staging/main.tf");
    await expect(verifyReleaseBundle(first.bundleDirectory)).resolves.toMatchObject({
      manifestSha256: first.manifestSha256,
    });
  });

  it.each([
    "trees/staging/landing/index.html",
    "snapshots/infra/terraform/ritual-investing/environments/staging/main.tf",
    "snapshots/supabase/migrations/20260830_release.sql",
    "snapshots/supabase/functions/waitlist/index.ts",
  ])("fails hard when checksummed content changes: %s", async (relativePath) => {
    const built = await buildReleaseBundle(await fixture());
    await writeFile(join(built.bundleDirectory, relativePath), "drift\n");
    await expect(verifyReleaseBundle(built.bundleDirectory)).rejects.toThrow(/checksum|digest/i);
  });

  it("excludes caches, state, plans, and env files but rejects secret-shaped source files", async () => {
    const options = await fixture();
    const terraformRoot = join(options.repositoryRoot, "infra/terraform/ritual-investing");
    await mkdir(join(terraformRoot, ".terraform/providers"), { recursive: true });
    await Promise.all([
      writeFile(join(terraformRoot, ".terraform/providers/cache"), "cache"),
      writeFile(join(terraformRoot, "terraform.tfstate"), "{}"),
      writeFile(join(terraformRoot, "saved.tfplan"), "plan"),
      writeFile(join(terraformRoot, ".env.prod"), "PUBLIC_VALUE=ignored"),
    ]);
    const built = await buildReleaseBundle(options);
    expect(built.manifest.files.map(({ path }) => path).join("\n")).not.toMatch(
      /\.terraform|tfstate|tfplan|\.env/i,
    );

    await writeFile(join(terraformRoot, "operator-private.pem"), "-----BEGIN PRIVATE KEY-----\nsecret\n");
    await expect(buildReleaseBundle({
      ...options,
      outputDirectory: join(options.repositoryRoot, "out-secret"),
    })).rejects.toThrow(/secret|private key|credential/i);
  });

  it("strictly validates canonical profiles and keeps prod landing withheld", async () => {
    const staging = parseReleaseProfile(stagingProfile(), "staging");
    const prod = parseReleaseProfile(prodProfile(), "prod");
    expect(profileReleaseEligibility(staging)).toEqual({ demo: true, landing: true, full: true });
    expect(profileReleaseEligibility(prod)).toEqual({ demo: true, landing: false, full: false });
    const packageRoot = resolve(import.meta.dirname, "../..");
    await expect(Promise.all(["staging", "prod"].map(async (environment) =>
      parseReleaseProfile(
        JSON.parse(await readFile(join(packageRoot, `config/release/${environment}.json`), "utf8")),
        environment as "staging" | "prod",
      ),
    ))).resolves.toEqual([expect.objectContaining({ environment: "staging" }), expect.objectContaining({ environment: "prod" })]);

    expect(() => parseReleaseProfile({ ...stagingProfile(), environment: "beta" }, "staging"))
      .toThrow(/environment/i);
    expect(() => parseReleaseProfile({ ...stagingProfile(), unexpected: true }, "staging"))
      .toThrow(/unknown/i);
    expect(() => parseReleaseProfile({ ...stagingProfile(), apiSecret: "not-even-a-real-secret" }, "staging"))
      .toThrow(/secret-shaped key/i);

    const badClass = structuredClone(stagingProfile());
    (badClass.targets as Record<string, any>).landing.backendDependency.classification = "sometimes";
    expect(() => parseReleaseProfile(badClass, "staging")).toThrow(/classification/i);

    const missingTarget = structuredClone(stagingProfile());
    delete (missingTarget.targets as Record<string, any>).landing.backendDependency.target;
    expect(() => parseReleaseProfile(missingTarget, "staging")).toThrow(/target/i);

    const wrongFingerprint = structuredClone(stagingProfile());
    (wrongFingerprint.targets as Record<string, any>).landing.backendDependency.requiredFingerprint = DIGEST;
    expect(() => parseReleaseProfile(wrongFingerprint, "staging")).toThrow(/fingerprint/i);

    const stagingInProd = structuredClone(prodProfile());
    (stagingInProd.targets as Record<string, any>).landing.host = "staging.just-build-this.app";
    expect(() => parseReleaseProfile(stagingInProd, "prod")).toThrow(/staging/i);

    const unapprovedProd = structuredClone(prodProfile());
    (unapprovedProd.targets as Record<string, any>).landing.backendDependency = {
      classification: "requires",
      requiredFingerprint: DIGEST,
      target: {
        status: "approved",
        supabaseProjectRef: STAGING_REF,
        waitlistUrl: `https://${STAGING_REF}.supabase.co/functions/v1/waitlist`,
      },
    };
    expect(() => parseReleaseProfile(unapprovedProd, "prod")).toThrow(/approved prod|staging/i);
  });

  it("probes only exact identity, revision, manifest, headers, and unknown-route policy", async () => {
    const calls: string[] = [];
    const fetchImpl: typeof fetch = async (input, init) => {
      const url = String(input);
      calls.push(`${init?.method ?? "GET"} ${url}`);
      if (url.endsWith("/version.json")) {
        return new Response(JSON.stringify({ schemaVersion: 1, revision: SHA, manifestSha256: DIGEST }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      if (url.endsWith("/__ritual-release-probe__/unknown")) return new Response("missing", { status: 404 });
      return new Response(null, {
        status: 200,
        headers: {
          "content-security-policy": "default-src 'none'",
          "x-content-type-options": "nosniff",
        },
      });
    };

    await expect(probePagesDeployment({
      origin: "https://demo-staging.just-build-this.app",
      expectedHost: "demo-staging.just-build-this.app",
      expectedRevision: SHA,
      expectedManifestSha256: DIGEST,
      requiredHeaders: {
        "content-security-policy": "default-src 'none'",
        "x-content-type-options": "nosniff",
      },
      unknownRoutePolicy: "not-found",
      fetchImpl,
    })).resolves.toMatchObject({ passed: true, host: "demo-staging.just-build-this.app" });
    expect(calls).toEqual([
      "GET https://demo-staging.just-build-this.app/version.json",
      "HEAD https://demo-staging.just-build-this.app/",
      "GET https://demo-staging.just-build-this.app/__ritual-release-probe__/unknown",
    ]);

    await expect(probePagesDeployment({
      origin: "https://hostile.example",
      expectedHost: "demo-staging.just-build-this.app",
      expectedRevision: SHA,
      expectedManifestSha256: DIGEST,
      requiredHeaders: {},
      unknownRoutePolicy: "not-found",
      fetchImpl,
    })).rejects.toThrow(/exact host/i);
  });
});
