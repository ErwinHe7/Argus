import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  assertTenantResource,
  createRequestDatabaseContext,
} from "../../src/db/request-context";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

describe("request-local tenant context", () => {
  it("accepts a verified server-resolved tenant and principal", () => {
    const context = createRequestDatabaseContext({
      accountId: "00000000-0000-4000-8000-000000000001",
      tenantId: "00000000-0000-4000-8000-000000000002",
      principal: "auth0|member-a",
      revocationEpoch: 3,
    });

    expect(context.tenantId).toBe("00000000-0000-4000-8000-000000000002");
    expect(Object.isFrozen(context)).toBe(true);
  });

  it("rejects tenant override and cross-tenant resource attachment", () => {
    const context = createRequestDatabaseContext({
      accountId: "00000000-0000-4000-8000-000000000001",
      tenantId: "00000000-0000-4000-8000-000000000002",
      principal: "auth0|member-a",
      revocationEpoch: 0,
    });

    expect(() =>
      assertTenantResource(context, "00000000-0000-4000-8000-000000000003"),
    ).toThrowError("resource_not_found");
  });

  it("rejects malformed resolver output and unverified subjects", () => {
    expect(() =>
      createRequestDatabaseContext({
        accountId: "not-a-uuid",
        tenantId: "00000000-0000-4000-8000-000000000002",
        principal: "",
        revocationEpoch: -1,
      }),
    ).toThrow();
  });

  it("keeps the working Neon seam scoped while isolating the portable Supabase transaction", async () => {
    const clientSource = await readFile(`${apiRoot}/src/db/client.ts`, "utf8");
    const portSource = await readFile(
      `${apiRoot}/src/db/database-port.ts`,
      "utf8",
    );
    const transactionSource = await readFile(
      `${apiRoot}/src/db/request-transaction.ts`,
      "utf8",
    );
    expect(clientSource).not.toMatch(/export\s+(?:async\s+)?function\s+openRequestConnection/i);
    expect(clientSource).toMatch(/withScopedRuntimeClient/i);
    expect(clientSource).toMatch(/set local role \$\{role\}/i);
    expect(clientSource).toMatch(/"ritual_identity_resolver"/i);
    expect(clientSource).toMatch(/"ritual_runtime"/i);
    expect(clientSource).toMatch(/set_config\('ritual\.tenant_id'/i);
    expect(clientSource).toMatch(/client\?\.release\(\)[\s\S]*pool\.end\(\)/i);
    expect(clientSource).toMatch(/@neondatabase\/serverless/i);
    expect(portSource).toMatch(/withDatabaseTransaction/i);
    expect(portSource).toMatch(/client\.release\(\)/i);
    expect(portSource).not.toMatch(/@neondatabase|drizzle-orm\/neon/i);
    expect(transactionSource).toMatch(/"argus_runtime"/i);
    expect(transactionSource).toMatch(/argus_private\.set_request_context/i);
    expect(transactionSource).toMatch(/from "\.\/database-port"/i);
    expect(transactionSource).not.toMatch(/from "\.\/client(?:\.ts)?"/i);
    expect(transactionSource).not.toMatch(/identityDatabaseUrl|runtimeDatabaseUrl|verifiedSubject/i);
  });
});
