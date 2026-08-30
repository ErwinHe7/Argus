import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it, vi } from "vitest";

import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../src/retained-app.ts";
import { StaffAuthorizationError } from "../../src/db/request-transaction.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789010";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const jobId = "018f3c2a-4b67-7a89-8abc-123456789012";

function fixture(input: {
  aal?: "aal1" | "aal2";
  repositories?: Partial<RetainedRepositorySet>;
}) {
  const repositories = {
    admin: {
      getStaffPrincipal: vi.fn(async () => ({
        user_id: userId,
        display_label: "Operator",
        permissions: ["operations:read"],
        revocation_epoch: 2,
      })),
      listAudit: vi.fn(async () => []),
      listEditorial: vi.fn(async () => []),
      createEditorial: vi.fn(),
      commandEditorial: vi.fn(),
      issueStepUp: vi.fn(async () =>
        "staff-step-up-receipt-000000000000000000000001"
      ),
    },
    adminOperations: {
      listJobs: vi.fn(async () => []),
      listPrivacy: vi.fn(async () => []),
      listAudit: vi.fn(async () => []),
      listBrokerageDiagnostics: vi.fn(async () => []),
      requestJobRetry: vi.fn(async () =>
        "018f3c2a-4b67-7a89-8abc-123456789099"
      ),
      requestPrivacyRetry: vi.fn(),
    },
    ...input.repositories,
  } as unknown as RetainedRepositorySet;
  const app = createRetainedApp({
    verifyAccessToken: vi.fn(async () => ({
      userId,
      sessionId,
      aal: input.aal ?? "aal2",
      issuedAt: 1,
    })),
    withRepositories: async (_claims, _transaction, callback) =>
      await callback(repositories),
    withPublicPreview: async (callback) =>
      await callback({
        listPublishedPage: vi.fn(async () => []),
        listPublished: vi.fn(async () => []),
        getPublished: vi.fn(async () => null),
      }),
    createPrivacyService: () => ({} as never),
    rateLimit: { allow: vi.fn(async () => ({ allowed: true })) },
  });
  const bindings = {
    environment: "test" as const,
    buildRevision: "test",
    consumerOrigins: Object.freeze(["https://app.example.test"]),
    adminOrigin: "https://admin.example.test",
    webAdmission: "open" as const,
  };
  return { app, bindings, repositories };
}

const headers = {
  authorization: "Bearer staff-token",
  origin: "https://admin.example.test",
};

describe("U11 Supabase staff authorization", () => {
  it("retries only final retained event types with concrete worker handlers", async () => {
    const workspaceRoot = resolve(
      dirname(fileURLToPath(import.meta.url)),
      "../../..",
    );
    const [u11, u15] = await Promise.all([
      readFile(
        resolve(
          workspaceRoot,
          "supabase/migrations/20260828145716_u11_admin_supabase_auth.sql",
        ),
        "utf8",
      ),
      readFile(
        resolve(
          workspaceRoot,
          "supabase/migrations/20260828152000_u15_webull_recovery.sql",
        ),
        "utf8",
      ),
    ]);
    const eventTypes = new Set(
      [...u11.matchAll(
        /'((?:briefing|media|content-report|privacy|webull)\.[a-z0-9_.-]+)'/g,
      )].map((match) => match[1]),
    );

    expect(eventTypes.size).toBeGreaterThan(0);
    expect(u11).not.toMatch(/admin\.(?:job|privacy)\.retry_requested/);
    expect(u11).toContain("job.status='dead_lettered'");
    expect(u11).toContain(
      "retained_job_handler(event.event_type)=requested_job.handler_name",
    );
    for (const eventType of eventTypes) {
      expect(u15).toContain(`'${eventType}'`);
      expect(u15).toContain(`when '${eventType}' then`);
    }
  });

  it("rejects AAL1 before any current-role repository call", async () => {
    const { app, bindings, repositories } = fixture({ aal: "aal1" });
    const response = await app.request(
      "/v1/admin/session",
      { headers },
      bindings,
    );
    expect(response.status).toBe(403);
    expect(repositories.admin.getStaffPrincipal).not.toHaveBeenCalled();
  });

  it("denies an inactive staff session instead of returning a null principal", async () => {
    const getStaffPrincipal = vi.fn(async () => null);
    const { app, bindings } = fixture({
      repositories: { admin: { getStaffPrincipal } as never },
    });
    const response = await app.request(
      "/v1/admin/session",
      { headers },
      bindings,
    );
    expect(response.status).toBe(403);
  });

  it("returns 403 for a stale JWT after session deletion on staff reads", async () => {
    const getStaffPrincipal = vi.fn(async () => {
      throw new StaffAuthorizationError();
    });
    const { app, bindings } = fixture({
      repositories: { admin: { getStaffPrincipal } as never },
    });
    const response = await app.request(
      "/v1/admin/session",
      { headers },
      bindings,
    );
    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({
      error: { code: "forbidden" },
    });
  });

  it("returns 403 for a stale JWT after session deletion on staff writes", async () => {
    const createEditorial = vi.fn(async () => {
      throw new StaffAuthorizationError();
    });
    const { app, bindings } = fixture({
      repositories: { admin: { createEditorial } as never },
    });
    const response = await app.request(
      "/v1/admin/editorial",
      {
        method: "POST",
        headers: { ...headers, "content-type": "application/json" },
        body: JSON.stringify({
          kind: "ritual",
          slug: "stale-session-write",
          payload: { title: "Never written" },
        }),
      },
      bindings,
    );
    expect(response.status).toBe(403);
    expect(createEditorial).toHaveBeenCalledOnce();
  });

  it("applies a permission downgrade on the next request", async () => {
    const listJobs = vi.fn(async () => {
      throw new StaffAuthorizationError();
    });
    const { app, bindings } = fixture({
      repositories: { adminOperations: { listJobs } as never },
    });
    const response = await app.request(
      "/v1/admin/operations/jobs",
      { headers },
      bindings,
    );
    expect(response.status).toBe(403);
    expect(listJobs).toHaveBeenCalledOnce();
  });

  it("requires an action-bound receipt for a sensitive retry", async () => {
    const requestJobRetry = vi.fn(async () => "outbox");
    const { app, bindings } = fixture({
      repositories: { adminOperations: { requestJobRetry } as never },
    });
    const response = await app.request(
      `/v1/admin/operations/jobs/${jobId}/retry`,
      {
        method: "POST",
        headers: {
          ...headers,
          "content-type": "application/json",
          "idempotency-key": "admin-job-retry-0001",
        },
        body: JSON.stringify({
          step_up_receipt: "staff-step-up-receipt-000000000000000000000001",
        }),
      },
      bindings,
    );
    expect(response.status).toBe(200);
    expect(requestJobRetry).toHaveBeenCalledWith(
      jobId,
      "admin-job-retry-0001",
      "staff-step-up-receipt-000000000000000000000001",
    );
  });

  it("returns only repository-redacted brokerage diagnostics", async () => {
    const safe = {
      correlation_id: "diag_387a61b64d67",
      kind: "provider_command",
      status: "manual_review",
      reason_code: "provider_error_redacted",
      observed_at: "2026-08-28T12:00:00.000Z",
    };
    const listBrokerageDiagnostics = vi.fn(async () => [safe]);
    const { app, bindings } = fixture({
      repositories: { adminOperations: { listBrokerageDiagnostics } as never },
    });
    const response = await app.request(
      "/v1/admin/operations/brokerage",
      { headers },
      bindings,
    );
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toContain("diag_387a61b64d67");
    expect(body).not.toMatch(
      /provider_account|client_order|balance|position|payload|credential/i,
    );
  });
});
