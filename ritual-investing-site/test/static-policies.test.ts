import { describe, expect, it } from "vitest";

import { renderDemoHeaders, renderLandingHeaders } from "../scripts/build-assets.ts";

describe("host-specific static response policy", () => {
  it.each([
    ["production", "https://demo.just-build-this.app", "https://just-build-this.app"],
    ["beta", "https://demo-beta.just-build-this.app", "https://beta.just-build-this.app"],
  ] as const)("locks %s landing and demo to their exact peer", (environment, demoOrigin, landingOrigin) => {
    const landing = renderLandingHeaders(environment);
    const demo = renderDemoHeaders(environment);

    expect(landing).toContain(`frame-src ${demoOrigin} https://challenges.cloudflare.com`);
    expect(landing).toContain("frame-ancestors 'none'");
    expect(landing).toContain("X-Frame-Options: DENY");
    expect(demo).toContain(`frame-ancestors ${landingOrigin}`);
    expect(demo).not.toContain("X-Frame-Options");
    expect(demo).toContain("script-src 'self' 'wasm-unsafe-eval'");
    for (const policy of `${landing}\n${demo}`.matchAll(/Content-Security-Policy: ([^\n]+)/g)) {
      expect(policy[1]).not.toMatch(/(^|\s)\*(?=\s|;|$)|unsafe-inline|(?<!wasm-)unsafe-eval/);
    }
  });

  it("marks only fingerprinted landing assets immutable and revalidates entry documents", () => {
    const headers = renderLandingHeaders("production");
    expect(headers).toContain("/assets/immutable/*");
    expect(headers).toContain("Cache-Control: public, max-age=31536000, immutable");
    expect(headers).toContain("Cache-Control: no-cache, no-store, must-revalidate");
  });

  it("keeps beta and both demo hosts out of indexes", () => {
    expect(renderLandingHeaders("production")).not.toContain("X-Robots-Tag: noindex");
    expect(renderLandingHeaders("beta")).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
    expect(renderDemoHeaders("production")).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
    expect(renderDemoHeaders("beta")).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
  });
});
