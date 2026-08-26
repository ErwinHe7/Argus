import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { createApp } from "../../src/app";
import { buildOpenApiDocument } from "../../src/contracts/openapi";
import {
  assertOperationFingerprint,
  fingerprintOperationContract,
} from "../../src/contracts/mobile-compatibility";
import { astrologyPutSchema } from "../../src/domains/accounts/schemas";

const apiRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const repositoryRoot = resolve(apiRoot, "..");

type CompatibilityManifest = {
  schema_version: 1;
  released_mobile: string;
  generated_client: string;
  api_major: number;
  support_window: {
    released_at: string;
    minimum_supported_through: string;
    minimum_days: number;
    n_adoption_percent: number;
    n_minus_1_zero_traffic_days: number;
    maximum_refresh_token_drain_days: number;
  };
  request_fixtures: Array<{
    operation_id: string;
    body: unknown;
  }>;
  operations: Array<{
    operation_id: string;
    method: string;
    path: string;
    required_responses: number[];
    contract_fingerprint: string;
  }>;
};

describe("released mobile N-1 to N compatibility", () => {
  it("accepts the released N-1 astrology update request", async () => {
    const manifest = JSON.parse(
      await readFile(
        `${apiRoot}/compatibility/mobile-client-n-minus-1.json`,
        "utf8",
      ),
    ) as CompatibilityManifest;
    const fixture = manifest.request_fixtures.find(
      ({ operation_id }) => operation_id === "putAstrologyProfile",
    );

    expect(fixture).toBeDefined();
    expect(astrologyPutSchema.safeParse(fixture?.body).success).toBe(true);
  });

  it("keeps every operation used by the released N-1 mobile client", async () => {
    const manifest = JSON.parse(
      await readFile(
        `${apiRoot}/compatibility/mobile-client-n-minus-1.json`,
        "utf8",
      ),
    ) as CompatibilityManifest;
    const document = buildOpenApiDocument(createApp());

    const releasedAt = Date.parse(`${manifest.support_window.released_at}T00:00:00Z`);
    const supportedThrough = Date.parse(
      `${manifest.support_window.minimum_supported_through}T00:00:00Z`,
    );
    expect((supportedThrough - releasedAt) / 86_400_000).toBeGreaterThanOrEqual(
      manifest.support_window.minimum_days,
    );
    expect(manifest.support_window).toMatchObject({
      minimum_days: 90,
      n_adoption_percent: 99,
      n_minus_1_zero_traffic_days: 14,
      maximum_refresh_token_drain_days: 30,
    });

    expect(document.info.version.startsWith(`${manifest.api_major}.`)).toBe(
      true,
    );
    for (const expected of manifest.operations) {
      const operation = (
        document.paths[expected.path] as Record<string, any> | undefined
      )?.[expected.method];
      expect(
        operation?.operationId,
        `${expected.method} ${expected.path}`,
      ).toBe(expected.operation_id);
      expect(Object.keys(operation?.responses ?? {}).map(Number)).toEqual(
        expect.arrayContaining(expected.required_responses),
      );
      expect(() =>
        assertOperationFingerprint(document, expected),
      ).not.toThrow();
    }
  });

  it("rejects response field removal and newly required request input", async () => {
    const manifest = JSON.parse(
      await readFile(
        `${apiRoot}/compatibility/mobile-client-n-minus-1.json`,
        "utf8",
      ),
    ) as CompatibilityManifest;
    const baseline = buildOpenApiDocument(createApp());
    const getMe = manifest.operations.find(
      ({ operation_id }) => operation_id === "getMe",
    )!;
    const contribution = manifest.operations.find(
      ({ operation_id }) => operation_id === "createDemoContribution",
    )!;

    const removedResponse = structuredClone(baseline) as any;
    delete removedResponse.components.schemas.MemberProfile.properties
      .display_name;
    expect(() => assertOperationFingerprint(removedResponse, getMe)).toThrow(
      /broke/,
    );

    const requiredInput = structuredClone(baseline) as any;
    requiredInput.paths[contribution.path][contribution.method].parameters.push(
      {
        name: "new_required_input",
        in: "query",
        required: true,
        schema: { type: "string" },
      },
    );
    expect(
      fingerprintOperationContract(requiredInput, {
        path: contribution.path,
        method: contribution.method,
        requiredResponses: contribution.required_responses,
      }),
    ).not.toBe(contribution.contract_fingerprint);
  });

  it("releases a new generated client while retaining the N-1 manifest", async () => {
    const baseline = JSON.parse(
      await readFile(
        `${apiRoot}/compatibility/mobile-client-n-minus-1.json`,
        "utf8",
      ),
    ) as CompatibilityManifest;
    const pubspec = await readFile(
      `${repositoryRoot}/ritual-investing-api-client/pubspec.yaml`,
      "utf8",
    );
    const current = pubspec.match(/^version:\s*([^\s]+)$/m)?.[1];
    expect(current).toBe("0.2.0");
    expect(current).not.toBe(baseline.generated_client);
  });
});
