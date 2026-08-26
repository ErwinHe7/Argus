import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        serviceBindings: {
          MEDIA_SCANNER: async () =>
            new Response('{"result":"clean"}', {
              headers: { "content-type": "application/json" },
            }),
          MEDIA_PROCESSOR: async () => new Response(new Uint8Array()),
          PUSH_PROVIDER: async () => new Response(null, { status: 202 }),
        },
      },
    }),
  ],
  test: {
    include: ["test/worker/**/*.test.ts"],
  },
});
