import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import {
  assembleAssets,
  injectTurnstileSiteKey,
  MAX_ASSET_BYTES,
  resolveTurnstileSiteKey,
} from "../scripts/build-assets.ts";

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
    expect(resolveTurnstileSiteKey("production", {
      TURNSTILE_SITE_KEY_PRODUCTION: "0x4AAAAAAAsyntheticProductionKey",
    }, true)).toBe("0x4AAAAAAAsyntheticProductionKey");
    expect(() => resolveTurnstileSiteKey("beta", {}, true)).toThrow(/beta.*site key/i);
    expect(resolveTurnstileSiteKey("beta", {}, false)).toBeUndefined();
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
});
