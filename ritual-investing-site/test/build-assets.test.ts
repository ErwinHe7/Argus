import { createHash } from "node:crypto";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import {
  assembleAssets,
  DEPLOYMENT_TARGETS,
  injectWaitlistConfiguration,
  injectTurnstileSiteKey,
  MAX_ASSET_BYTES,
  renderDemoHeaders,
  renderLandingHeaders,
  renderMemberHeaders,
  resolveMemberStagingAssemblyInputs,
  resolveWaitlistFunctionUrl,
  resolveTurnstileSiteKey,
} from "../scripts/build-assets.ts";

const MEMBER_PROJECT_REF = "abcdefghijklmnopqrst";
const MEMBER_ORIGIN = `https://${MEMBER_PROJECT_REF}.supabase.co`;
const RITUAL_BETA_BRANCH_REF = "zbgjjufjkhfhirbuuolv";
const RITUAL_BETA_BRANCH_ORIGIN = `https://${RITUAL_BETA_BRANCH_REF}.supabase.co`;
const RITUAL_BETA_KEY = "sb_publishable_A4POPCI9WnO-VnSb1IQXFg_4GM58St0";
const MEMBER_KEY = "sb_publishable_member_beta_fixture_1234567890";
const MEMBER_INPUTS = {
  projectRef: MEMBER_PROJECT_REF,
  publishableKeySha256: createHash("sha256").update(MEMBER_KEY).digest("hex"),
  supabaseOrigin: MEMBER_ORIGIN,
} as const;
const RITUAL_BETA_INPUTS = {
  projectRef: RITUAL_BETA_BRANCH_REF,
  publishableKeySha256: createHash("sha256").update(RITUAL_BETA_KEY).digest("hex"),
  supabaseOrigin: RITUAL_BETA_BRANCH_ORIGIN,
} as const;

function contentSecurityPolicyDirective(headers: string, name: string): string | undefined {
  const policy = /^  Content-Security-Policy: (.+)$/m.exec(headers)?.[1];
  return policy?.split("; ").find((directive) => directive.startsWith(`${name} `));
}

async function fixture(): Promise<{ source: string; destination: string }> {
  const root = await mkdtemp(join(tmpdir(), "ritual-site-assets-"));
  const source = join(root, "source");
  const destination = join(root, "destination");
  await mkdir(source);
  await writeFile(join(source, "index.html"), '<script src="main.dart.js"></script>');
  await writeFile(join(source, "main.dart.js"), "console.log('demo');");
  await writeFile(join(source, "flutter_service_worker.js"), "");
  return { source, destination };
}

describe("deterministic demo asset assembly", () => {
  it("injects a provisioned public Turnstile site key through the one build seam", () => {
    const html = '<div data-turnstile-site-key=""></div>';
    expect(injectTurnstileSiteKey(html, "0x4AAAAAAAsyntheticPublicKey")).toContain(
      'data-turnstile-site-key="0x4AAAAAAAsyntheticPublicKey"',
    );
    expect(() => injectTurnstileSiteKey(html, "short")).toThrow(/site key/i);
    expect(() => injectTurnstileSiteKey("<div></div>", "0x4AAAAAAAsyntheticPublicKey")).toThrow(/exactly one/i);
  });

  it("requires both environment-specific site keys for a release assembly", () => {
    expect(resolveTurnstileSiteKey("prod", {
      TURNSTILE_SITE_KEY_PROD: "0x4AAAAAAAsyntheticProductionKey",
    }, true)).toBe("0x4AAAAAAAsyntheticProductionKey");
    expect(() => resolveTurnstileSiteKey("staging", {}, true)).toThrow(/staging.*site key/i);
    expect(resolveTurnstileSiteKey("staging", {}, false)).toBeUndefined();
  });

  it("accepts only an exact public Supabase waitlist endpoint and injects it once", () => {
    const endpoint = "https://project-ref.supabase.co/functions/v1/waitlist";
    expect(resolveWaitlistFunctionUrl("prod", {
      WAITLIST_FUNCTION_URL_PROD: endpoint,
    }, true)).toBe(endpoint);
    expect(resolveWaitlistFunctionUrl("staging", {}, false)).toBeUndefined();
    for (const invalid of [
      "http://project-ref.supabase.co/functions/v1/waitlist",
      "https://project-ref.supabase.co/functions/v1/worker",
      "https://evil.example/functions/v1/waitlist",
      `${endpoint}?apikey=forbidden`,
    ]) {
      expect(() => resolveWaitlistFunctionUrl("prod", {
        WAITLIST_FUNCTION_URL_PROD: invalid,
      }, true)).toThrow(/Supabase waitlist function URL/i);
    }
    const html = '<form action="" method="post" data-waitlist-form data-waitlist-enabled="false"></form>';
    expect(injectWaitlistConfiguration(html, endpoint)).toContain(
      `action="${endpoint}" method="post" data-waitlist-form data-waitlist-enabled="true"`,
    );
  });

  it("publishes only canonical staging and prod asset directories", () => {
    expect(DEPLOYMENT_TARGETS).toEqual([
      {
        environment: "staging",
        landingDirectory: "dist/landing-staging",
        demoDirectory: "dist/demo-staging",
      },
      {
        environment: "prod",
        landingDirectory: "dist/landing-prod",
        demoDirectory: "dist/demo-prod",
      },
    ]);
  });

  it("copies validated assets, drops Flutter's zero-byte service-worker placeholder, and emits a hash manifest", async () => {
    const paths = await fixture();
    const manifest = await assembleAssets(paths);

    expect(manifest.files.map((file) => file.path)).toEqual(["index.html", "main.dart.js"]);
    expect(manifest.files.every((file) => file.sha256.length === 64)).toBe(true);
    await expect(readFile(join(paths.destination, "flutter_service_worker.js"), "utf8")).rejects.toThrow();
    expect(JSON.parse(await readFile(join(paths.destination, "asset-manifest.json"), "utf8"))).toEqual(manifest);
    expect(await assembleAssets(paths)).toEqual(manifest);
  });

  it("rejects an absent referenced file", async () => {
    const paths = await fixture();
    await writeFile(join(paths.source, "index.html"), '<script src="missing.js"></script>');
    await expect(assembleAssets(paths)).rejects.toThrow(/missing referenced asset/i);
  });

  it("rejects references to excluded output and remote runtime assets", async () => {
    for (const reference of [
      "flutter_service_worker.js",
      "debug.symbols",
      "https://cdn.example.invalid/runtime.js",
      "//cdn.example.invalid/runtime.js",
    ]) {
      const paths = await fixture();
      if (reference === "debug.symbols") await writeFile(join(paths.source, reference), "symbols");
      await writeFile(join(paths.source, "index.html"), `<script src="${reference}"></script>`);
      await expect(assembleAssets(paths)).rejects.toThrow(/missing referenced asset|remote runtime asset/i);
    }
  });

  it("validates Flutter's dynamic entrypoint and self-hosted runtime references", async () => {
    const paths = await fixture();
    await writeFile(join(paths.source, "index.html"), '<script src="flutter_bootstrap.js"></script>');
    await writeFile(
      join(paths.source, "flutter_bootstrap.js"),
      '_flutter.buildConfig = {"builds":[{"mainJsPath":"main.dart.js"}],"wasmHashes":{},"useLocalCanvasKit":true};',
    );
    await rm(join(paths.source, "main.dart.js"));
    await expect(assembleAssets(paths)).rejects.toThrow(/missing referenced asset.*main\.dart\.js/i);

    await writeFile(join(paths.source, "main.dart.js"), "console.log('demo');");
    await writeFile(
      join(paths.source, "flutter_bootstrap.js"),
      '_flutter.buildConfig = {"builds":[{"mainJsPath":"main.dart.js"}],"wasmHashes":{},"useLocalCanvasKit":false};',
    );
    await expect(assembleAssets(paths)).rejects.toThrow(/remote Flutter runtime assets/i);
  });

  it("rejects oversized, source-map, provider, and non-empty service-worker artifacts", async () => {
    for (const [name, contents, expected] of [
      ["oversized.bin", new Uint8Array(MAX_ASSET_BYTES + 1), /25 MiB/],
      ["main.dart.js.map", "{}", /source map/],
      ["main.dart.js", "https://api.just-build-this.app/v1/session/bootstrap", /provider boundary/],
      ["flutter_service_worker.js", "self.addEventListener('fetch', () => {})", /service worker/],
    ] as const) {
      const paths = await fixture();
      await writeFile(join(paths.source, name), contents);
      await expect(assembleAssets(paths)).rejects.toThrow(expected);
    }
  });

  it("rejects every Pages compute entrypoint and keeps Supabase out of demo artifacts", async () => {
    for (const name of ["_worker.js", "_routes.json", "_redirects", "functions/index.js"]) {
      const paths = await fixture();
      await mkdir(join(paths.source, "functions"), { recursive: true });
      await writeFile(join(paths.source, name), "export default {};");
      await expect(assembleAssets(paths)).rejects.toThrow(/compute artifact/i);
    }
    const serviceWorker = await fixture();
    await writeFile(join(serviceWorker.source, "service-worker.js"), "");
    await expect(assembleAssets(serviceWorker)).rejects.toThrow(/service worker/i);
    const paths = await fixture();
    await writeFile(join(paths.source, "main.dart.js"), "https://project.supabase.co");
    await expect(assembleAssets({ ...paths, surface: "demo" })).rejects.toThrow(
      /demo provider boundary/i,
    );
  });

  it("requires exact beta assembly inputs and accepts the verified persistent beta branch", () => {
    expect(resolveMemberStagingAssemblyInputs({
      MEMBER_BETA_SUPABASE_PROJECT_REF: MEMBER_PROJECT_REF,
      MEMBER_BETA_SUPABASE_ORIGIN: MEMBER_ORIGIN,
      MEMBER_BETA_SUPABASE_PUBLISHABLE_KEY_SHA256: MEMBER_INPUTS.publishableKeySha256,
    })).toEqual(MEMBER_INPUTS);
    expect(resolveMemberStagingAssemblyInputs({
      MEMBER_BETA_SUPABASE_PROJECT_REF: RITUAL_BETA_BRANCH_REF,
      MEMBER_BETA_SUPABASE_ORIGIN: RITUAL_BETA_BRANCH_ORIGIN,
      MEMBER_BETA_SUPABASE_PUBLISHABLE_KEY_SHA256: RITUAL_BETA_INPUTS.publishableKeySha256,
    })).toEqual(RITUAL_BETA_INPUTS);
  });

  it("assembles only the exact member beta Supabase origin, Edge URL, and key fingerprint", async () => {
    const paths = await fixture();
    await writeFile(
      join(paths.source, "main.dart.js"),
      `${RITUAL_BETA_BRANCH_ORIGIN} ${RITUAL_BETA_BRANCH_ORIGIN}/functions/v1/api /v1/session/bootstrap ${RITUAL_BETA_KEY}`,
    );
    await expect(assembleAssets({ ...paths, surface: "member", memberStaging: RITUAL_BETA_INPUTS }))
      .resolves.toMatchObject({ algorithm: "sha256", fileCount: 2 });

    await writeFile(join(paths.source, "main.dart.js"), `${MEMBER_ORIGIN}/functions/v1/api ${MEMBER_KEY} https://otherprojectref00001.supabase.co`);
    await expect(assembleAssets({ ...paths, surface: "member", memberStaging: MEMBER_INPUTS }))
      .rejects.toThrow(/unapproved Supabase origin/i);

    await writeFile(join(paths.source, "main.dart.js"), `${MEMBER_ORIGIN}/functions/v1/api sb_publishable_wrong_key_1234567890`);
    await expect(assembleAssets({ ...paths, surface: "member", memberStaging: MEMBER_INPUTS }))
      .rejects.toThrow(/fingerprint/i);
  });

  it("renders deny-first member headers with callback no-store and only named immutable assets", () => {
    const headers = renderMemberHeaders(MEMBER_ORIGIN, ["assets/app.1234abcd.js"]);
    expect(headers).toContain("default-src 'none'");
    expect(headers).toContain("script-src 'self' 'wasm-unsafe-eval'");
    expect(contentSecurityPolicyDirective(headers, "img-src")).toBe("img-src 'self' blob:");
    expect(contentSecurityPolicyDirective(renderLandingHeaders("staging"), "img-src"))
      .toBe("img-src 'self'");
    expect(contentSecurityPolicyDirective(renderDemoHeaders("staging"), "img-src"))
      .toBe("img-src 'self' data: blob:");
    expect(headers).toContain(`connect-src 'self' ${MEMBER_ORIGIN}`);
    expect(headers).toContain("X-Frame-Options: DENY");
    expect(headers).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
    expect(headers).toContain("/mobile/argus-auth/callback\n  Cache-Control: no-store");
    expect(headers).toContain("/auth/recovery\n  Cache-Control: no-store");
    expect(headers).toContain("/assets/app.1234abcd.js\n  Cache-Control: public, max-age=31536000, immutable");
    expect(headers).not.toMatch(/(^|[ '])\*($|[ ;'])|unsafe-inline|(?<!wasm-)unsafe-eval|data:/);
  });
});
