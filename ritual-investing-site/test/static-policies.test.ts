import { describe, expect, it } from "vitest";

import { renderDemoHeaders, renderLandingHeaders } from "../scripts/build-assets.ts";

describe("host-specific static response policy", () => {
  it.each([
    ["prod", "https://demo.just-build-this.app", "https://just-build-this.app"],
    ["staging", "https://demo-staging.just-build-this.app", "https://staging.just-build-this.app"],
  ] as const)("locks %s landing and demo to their exact peer", (environment, demoOrigin, landingOrigin) => {
    const waitlist = "https://project-ref.supabase.co/functions/v1/waitlist";
    const landing = renderLandingHeaders(environment, waitlist);
    const demo = renderDemoHeaders(environment);

    expect(landing).toContain(`frame-src ${demoOrigin} https://challenges.cloudflare.com`);
    expect(landing).toContain("frame-ancestors 'none'");
    expect(landing).toContain("X-Frame-Options: DENY");
    expect(demo).toContain(`frame-ancestors ${landingOrigin}`);
    expect(demo).not.toContain("X-Frame-Options");
    expect(demo).toContain("script-src 'self' 'wasm-unsafe-eval'");
    expect(landing).toContain("base-uri 'none'");
    expect(landing).toContain("form-action https://project-ref.supabase.co");
    expect(landing).toContain("connect-src 'self' https://challenges.cloudflare.com https://project-ref.supabase.co");
    expect(demo).toContain("base-uri 'self'");
    expect(demo).toContain("style-src 'self'; style-src-elem 'self' 'unsafe-inline'; style-src-attr 'none'");
    expect(demo).not.toContain("style-src 'self' 'unsafe-inline'");
    expect(demo.match(/unsafe-inline/g)).toHaveLength(1);
    expect(landing).not.toContain("unsafe-inline");
    for (const policy of `${landing}\n${demo}`.matchAll(/Content-Security-Policy: ([^\n]+)/g)) {
      expect(policy[1]).not.toMatch(/(^|\s)\*(?=\s|;|$)|(?<!wasm-)unsafe-eval/);
    }
  });

  it("marks only fingerprinted landing assets immutable and revalidates entry documents", () => {
    const headers = renderLandingHeaders("prod");
    expect(headers).toContain("/assets/immutable/*");
    expect(headers).toContain("Cache-Control: public, max-age=31536000, immutable");
    expect(headers).toContain("Cache-Control: no-cache, no-store, must-revalidate");
  });

  it("keeps preview waitlist submission disabled when no endpoint is injected", () => {
    const headers = renderLandingHeaders("staging");
    expect(headers).toContain("form-action 'none'");
    expect(headers).not.toContain("supabase.co");
  });

  it("keeps staging and both demo hosts out of indexes", () => {
    expect(renderLandingHeaders("prod")).not.toContain("X-Robots-Tag: noindex");
    expect(renderLandingHeaders("staging")).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
    expect(renderDemoHeaders("prod")).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
    expect(renderDemoHeaders("staging")).toContain("X-Robots-Tag: noindex, nofollow, noarchive");
  });
});
