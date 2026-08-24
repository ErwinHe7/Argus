import { describe, expect, it, vi } from "vitest";

import { createApp } from "../../src/app";
import { VersionConflictError } from "../../src/domains/accounts/repository";
import { createTestRsaKey } from "../support/jwt";
import {
  fakeRateLimit,
  memberToken,
  resolvedMemberAccount,
  testBindings,
} from "../support/security-fixtures";

describe("member account state", () => {
  const auth0Key = createTestRsaKey("member-account-key");

  function app(repository: Record<string, unknown>) {
    return createApp({
      dependencies: {
        auth0Keys: [auth0Key.publicJwk],
        accountResolver: vi.fn(async () => resolvedMemberAccount),
        memberRepository: repository,
      },
    } as never);
  }

  it("returns the server-owned profile without a tenant field", async () => {
    const application = app({
      getAccount: vi.fn(async () => ({
        account: { id: resolvedMemberAccount.accountId, status: "active" },
        profile: { display_name: "Ritual Member", locale: "en-US", version: 1 },
      })),
    });

    const response = await application.request(
      "/v1/me",
      {
        headers: { authorization: `Bearer ${memberToken(auth0Key)}` },
      },
      testBindings(),
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(JSON.stringify(body)).not.toContain("tenant_id");
    expect(body).toMatchObject({
      data: { profile: { display_name: "Ritual Member" } },
    });
    expect(response.headers.get("etag")).toBe('"v1"');
  });

  it("rejects precise astrology location/time fields before persistence", async () => {
    const putAstrologyProfile = vi.fn();
    const application = app({ putAstrologyProfile });
    const response = await application.request(
      "/v1/me/astrology-profile",
      {
        method: "PUT",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key)}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          birth_date: "1990-02-03",
          derived_profile_code: "lunar_patient",
          algorithm_version: "v1",
          birth_time: "05:40",
          birthplace: "New York",
        }),
      },
      testBindings(),
    );

    expect(response.status).toBe(422);
    expect(putAstrologyProfile).not.toHaveBeenCalled();
  });

  it("records one idempotent consent decision for a policy version", async () => {
    const createConsent = vi.fn(async () => ({
      id: "018f3c2a-4b67-7a89-8abc-123456789061",
      policy_code: "terms",
      policy_version: "2026-08",
      decision: "accepted",
      recorded_at: "2026-08-24T04:00:00.000Z",
    }));
    const application = app({ createConsent });
    const request = () =>
      application.request(
        "/v1/me/consents",
        {
          method: "POST",
          headers: {
            authorization: `Bearer ${memberToken(auth0Key)}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            policy_code: "terms",
            policy_version: "2026-08",
            decision: "accepted",
          }),
        },
        testBindings(),
      );

    expect((await request()).status).toBe(200);
    expect((await request()).status).toBe(200);
    expect(createConsent).toHaveBeenCalledTimes(2);
  });

  it("accepts valid uncommon IANA zones and rejects invalid/control input", async () => {
    const patchPreferences = vi.fn(
      async (_context: unknown, patch: Record<string, unknown>) => ({
        ...patch,
        theme_mode: "system",
        ritual_mode: "tarot",
        locale: "en-US",
        version: 2,
      }),
    );
    const application = app({ patchPreferences });
    const request = (timezone: string) =>
      application.request(
        "/v1/me/preferences",
        {
          method: "PATCH",
          headers: {
            authorization: `Bearer ${memberToken(auth0Key)}`,
            "content-type": "application/json",
            "if-match": '"v1"',
          },
          body: JSON.stringify({ timezone }),
        },
        testBindings(),
      );
    expect((await request("Pacific/Chatham")).status).toBe(200);
    expect((await request("Mars/Olympus\u0000")).status).toBe(422);
    expect(patchPreferences).toHaveBeenCalledTimes(1);
  });

  it("creates an investor singleton without If-Match but refuses an unversioned overwrite", async () => {
    const putInvestorProfile = vi
      .fn()
      .mockResolvedValueOnce({
        goal_type: "calm_fund",
        time_horizon: "long",
        risk_comfort: "moderate",
        version: 1,
        is_demo: true,
      })
      .mockRejectedValueOnce(new VersionConflictError());
    const application = app({ putInvestorProfile });
    const request = () =>
      application.request(
        "/v1/me/investor-profile",
        {
          method: "PUT",
          headers: {
            authorization: `Bearer ${memberToken(auth0Key)}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            goal_type: "calm_fund",
            time_horizon: "long",
            risk_comfort: "moderate",
          }),
        },
        testBindings(),
      );

    const created = await request();
    expect(created.status).toBe(200);
    expect(created.headers.get("etag")).toBe('"v1"');
    expect((await request()).status).toBe(409);
    expect(putInvestorProfile).toHaveBeenNthCalledWith(
      1,
      expect.any(Object),
      expect.any(Object),
      undefined,
    );
  });

  it("creates astrology without If-Match but refuses an unversioned overwrite", async () => {
    const profile = {
      birth_date: "1990-02-03",
      derived_profile_code: "lunar_patient",
      algorithm_version: "v1",
      enabled_at: "2026-08-24T04:00:00.000Z",
      version: 1,
    };
    const putAstrologyProfile = vi
      .fn()
      .mockResolvedValueOnce(profile)
      .mockRejectedValueOnce(new VersionConflictError());
    const application = app({ putAstrologyProfile });
    const request = () =>
      application.request(
        "/v1/me/astrology-profile",
        {
          method: "PUT",
          headers: {
            authorization: `Bearer ${memberToken(auth0Key)}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            birth_date: profile.birth_date,
            derived_profile_code: profile.derived_profile_code,
            algorithm_version: profile.algorithm_version,
          }),
        },
        testBindings(),
      );

    const created = await request();
    expect(created.status).toBe(200);
    expect(created.headers.get("etag")).toBe('"v1"');
    expect((await request()).status).toBe(409);
    expect(putAstrologyProfile).toHaveBeenNthCalledWith(
      1,
      expect.any(Object),
      expect.any(Object),
      undefined,
    );
  });

  it("deletes missing astrology idempotently but reports a stale existing version", async () => {
    const deleteAstrologyProfile = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(new VersionConflictError());
    const application = app({ deleteAstrologyProfile });
    const remove = (ifMatch?: string) =>
      application.request(
        "/v1/me/astrology-profile",
        {
          method: "DELETE",
          headers: {
            authorization: `Bearer ${memberToken(auth0Key)}`,
            ...(ifMatch === undefined ? {} : { "if-match": ifMatch }),
          },
        },
        testBindings(),
      );

    expect((await remove()).status).toBe(204);
    expect((await remove('"v1"')).status).toBe(409);
  });

  it("normalizes locale input and returns dependency failures without cacheable details", async () => {
    const application = app({
      patchProfile: vi.fn(async () => {
        throw new Error("database host secret");
      }),
    });
    const invalid = await application.request(
      "/v1/me/profile",
      {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key)}`,
          "content-type": "application/json",
          "if-match": '"v1"',
        },
        body: JSON.stringify({ locale: "en_US" }),
      },
      testBindings(),
    );
    expect(invalid.status).toBe(422);

    const failed = await application.request(
      "/v1/me/profile",
      {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${memberToken(auth0Key)}`,
          "content-type": "application/json",
          "if-match": '"v1"',
        },
        body: JSON.stringify({ locale: "en-US" }),
      },
      testBindings(),
    );
    expect(failed.status).toBe(503);
    expect(failed.headers.get("cache-control")).toContain("no-store");
    expect(JSON.stringify(await failed.json())).not.toContain(
      "database host secret",
    );
  });

  it("uses one method-aware limiter and the correct permission on singleton paths", async () => {
    const astrology = {
      birth_date: "1990-02-03",
      derived_profile_code: "lunar_patient",
      algorithm_version: "v1",
      enabled_at: "2026-08-24T04:00:00.000Z",
      version: 1,
    };
    const investor = {
      goal_type: "calm_fund",
      time_horizon: "long",
      risk_comfort: "moderate",
      version: 1,
      is_demo: true,
    };
    const application = app({
      getAstrologyProfile: vi.fn(async () => astrology),
      putAstrologyProfile: vi.fn(async () => astrology),
      getInvestorProfile: vi.fn(async () => investor),
      putInvestorProfile: vi.fn(async () => investor),
    });
    const read = fakeRateLimit();
    const write = fakeRateLimit();
    const bindings = {
      ...testBindings(),
      RL_MEMBER_READ: read,
      RL_MEMBER_WRITE: write,
    };
    const both = {
      authorization: `Bearer ${memberToken(auth0Key)}`,
      "content-type": "application/json",
    };

    expect(
      (
        await application.request(
          "/v1/me/astrology-profile",
          { headers: both },
          bindings,
        )
      ).status,
    ).toBe(200);
    expect(
      (
        await application.request(
          "/v1/me/astrology-profile",
          {
            method: "PUT",
            headers: both,
            body: JSON.stringify({
              birth_date: astrology.birth_date,
              derived_profile_code: astrology.derived_profile_code,
              algorithm_version: astrology.algorithm_version,
            }),
          },
          bindings,
        )
      ).status,
    ).toBe(200);
    expect(
      (
        await application.request(
          "/v1/me/investor-profile",
          { headers: both },
          bindings,
        )
      ).status,
    ).toBe(200);
    expect(
      (
        await application.request(
          "/v1/me/investor-profile",
          {
            method: "PUT",
            headers: both,
            body: JSON.stringify({
              goal_type: investor.goal_type,
              time_horizon: investor.time_horizon,
              risk_comfort: investor.risk_comfort,
            }),
          },
          bindings,
        )
      ).status,
    ).toBe(200);
    expect(read.keys).toHaveLength(4);
    expect(write.keys).toHaveLength(4);

    const readOnly = {
      ...both,
      authorization: `Bearer ${memberToken(auth0Key, { permissions: ["read:self"] })}`,
    };
    const writeOnly = {
      ...both,
      authorization: `Bearer ${memberToken(auth0Key, { permissions: ["write:self"] })}`,
    };
    expect(
      (
        await application.request(
          "/v1/me/astrology-profile",
          {
            method: "PUT",
            headers: readOnly,
            body: JSON.stringify({
              birth_date: astrology.birth_date,
              derived_profile_code: astrology.derived_profile_code,
              algorithm_version: astrology.algorithm_version,
            }),
          },
          testBindings(),
        )
      ).status,
    ).toBe(403);
    expect(
      (
        await application.request(
          "/v1/me/investor-profile",
          { headers: writeOnly },
          testBindings(),
        )
      ).status,
    ).toBe(403);
  });
});
