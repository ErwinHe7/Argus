import { resolve } from "node:path";

import { describe, expect, it } from "vitest";
import { experimental_readRawConfig } from "wrangler";

function betaConfig() {
  return experimental_readRawConfig({
    config: resolve(process.cwd(), "wrangler.beta.jsonc"),
  }).rawConfig;
}

describe("beta member authentication", () => {
  it("allows the member app Auth0 client used by the beta build", () => {
    expect(betaConfig().vars.AUTH0_MEMBER_CLIENT_IDS).toBe(
      "VIFuQLVxk6baW27jS9TzQ22pIV8lAqHz",
    );
  });
});
