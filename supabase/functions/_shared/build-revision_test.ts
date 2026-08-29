import { assertEquals } from "jsr:@std/assert@1.0.15";

import { withBuildRevisionHeader } from "./build-revision.ts";

Deno.test("build revision wrapper marks non-mutating error probes", async () => {
  const handler = withBuildRevisionHeader(
    () => new Response(null, { status: 405 }),
    "0123456789abcdef0123456789abcdef01234567",
  );
  const response = await handler(new Request("https://example.test/"));
  assertEquals(response.status, 405);
  assertEquals(
    response.headers.get("x-argus-build-revision"),
    "0123456789abcdef0123456789abcdef01234567",
  );
});
