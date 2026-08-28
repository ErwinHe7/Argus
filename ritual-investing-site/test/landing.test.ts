import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const ROOT = resolve(import.meta.dirname, "..");

describe("semantic landing and privacy contract", () => {
  it("keeps the product narrative, demo disclosures, and waitlist usable in authored HTML", async () => {
    const html = await readFile(resolve(ROOT, "public/index.html"), "utf8");
    expect(html).toContain("<main");
    expect(html).toMatch(/Daily Ritual/);
    expect(html).toMatch(/Asset Codex/);
    expect(html).toMatch(/Coven/);
    expect(html).toMatch(/Grimoire/);
    expect(html).toMatch(/portfolio/i);
    expect(html).toMatch(/Demo/);
    expect(html).toMatch(/simulated investing/i);
    expect(html).toMatch(/not financial advice/i);
    expect(html).toContain('sandbox="allow-scripts allow-same-origin"');
    expect(html).toContain('title="Explore the Ritual Investing product demo"');
    expect(html).toContain('type="email"');
    expect(html).toContain('name="consent"');
    expect(html).toContain('value="waitlist-v1-2026-08-25"');
    expect(html).toContain('href="/privacy/waitlist/"');
    expect(html).toContain('aria-live="polite"');
    expect(html).toContain('action=""');
    expect(html).toContain('data-waitlist-enabled="false"');
    expect(html).not.toMatch(/<script(?![^>]*src=)/i);
  });

  it("publishes the versioned minimal-data and restore-safe privacy promise", async () => {
    const html = await readFile(resolve(ROOT, "public/privacy/waitlist/index.html"), "utf8");
    expect(html).toContain("waitlist-v1-2026-08-25");
    expect(html).toMatch(/normalized email/i);
    expect(html).toMatch(/notice version/i);
    expect(html).toMatch(/server submission timestamp/i);
    expect(html).toMatch(/provisional and unverified/i);
    expect(html).toMatch(/mailbox confirmation/i);
    expect(html).toContain("privacy@just-build-this.app");
    expect(html).toMatch(/mailbox possession/i);
    expect(html).toMatch(/before 24 months/i);
    expect(html).toMatch(/restore/i);
    expect(html).toMatch(/Cloudflare/);
    expect(html).toMatch(/Turnstile/);
    expect(html).toMatch(/Supabase/);
    expect(html).not.toMatch(/Neon/);
  });

  it("uses the production canonical and crawl artifacts", async () => {
    const [html, robots, sitemap] = await Promise.all([
      readFile(resolve(ROOT, "public/index.html"), "utf8"),
      readFile(resolve(ROOT, "public/robots.txt"), "utf8"),
      readFile(resolve(ROOT, "public/sitemap.xml"), "utf8"),
    ]);
    expect(html).toContain('<link rel="canonical" href="https://just-build-this.app/">');
    expect(html).toContain('<meta name="robots" content="index,follow">');
    expect(robots).toContain("Allow: /");
    expect(sitemap).toContain("https://just-build-this.app/");
    expect(sitemap).toContain("https://just-build-this.app/privacy/waitlist/");
  });
});
