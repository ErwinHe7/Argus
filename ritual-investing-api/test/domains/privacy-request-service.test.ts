import { describe, expect, it, vi } from "vitest";

import type { DatabaseTransaction } from "../../src/db/database-port.ts";
import { RepositoryStepUpRequiredError } from "../../src/db/repository-support.ts";
import {
  createPrivacyRequestService,
  type PrivacyRequestRepository,
} from "../../src/domains/privacy/service.ts";
import { sha256TextHex } from "../../src/security/sha256.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const otherUserId = "018f3c2a-4b67-7a89-8abc-123456789002";
const sessionId = "018f3c2a-4b67-7a89-8abc-123456789011";
const requestId = "018f3c2a-4b67-7a89-8abc-123456789041";
const leaseId = "018f3c2a-4b67-7a89-8abc-123456789042";

type FixtureOptions = Readonly<{
  userId?: string;
  expiresInSeconds?: number;
  signedUrl?: string;
  confirmError?: Error;
  now?: () => number;
}>;

function fixture(options: FixtureOptions = {}) {
  const events: string[] = [];
  const transactions: DatabaseTransaction[] = [];
  const transactionOrdinals = new WeakMap<object, number>();
  let transactionCount = 0;

  const list = vi.fn(async () => {
    events.push("repository:list");
    return [{ id: requestId }];
  });
  const requestExport = vi.fn(async (scopedDedupeKey: string) => {
    events.push("repository:request-export");
    return { id: requestId, scopedDedupeKey };
  });
  const requestDeletion = vi.fn(
    async (
      receiptHash: string,
      requestSessionId: string,
      dedupeKey: string,
    ) => {
      events.push("repository:request-deletion");
      return { id: requestId, receiptHash, requestSessionId, dedupeKey };
    },
  );
  const getDeletionTombstone = vi.fn(async () => {
    events.push("repository:get-deletion-tombstone");
    return { id: "tombstone-id" };
  });
  const prepareDownload = vi.fn(async (preparedRequestId: string) => {
    events.push("repository:prepare-download");
    expect(preparedRequestId).toBe(requestId);
    return {
      access_lease_id: leaseId,
      bucket_id: "privacy-exports",
      object_path: `${userId}/export.zip`,
      expires_in_seconds: options.expiresInSeconds ?? 30,
    };
  });
  const confirmDownload = vi.fn(async (preparedLeaseId: string) => {
    events.push("repository:confirm-download");
    expect(preparedLeaseId).toBe(leaseId);
    if (options.confirmError !== undefined) throw options.confirmError;
  });

  const repository = vi.fn(
    (database: DatabaseTransaction): PrivacyRequestRepository => {
      const ordinal = transactionOrdinals.get(database);
      if (ordinal === undefined) {
        throw new Error("repository_outside_transaction");
      }
      events.push(`transaction:${ordinal}:repository-bound`);
      return {
        list,
        requestExport,
        requestDeletion,
        getDeletionTombstone,
        prepareDownload,
        confirmDownload,
      };
    },
  );
  const withMemberTransaction = async <T>(
    callback: (database: DatabaseTransaction) => Promise<T>,
  ): Promise<T> => {
    const ordinal = ++transactionCount;
    const database = Object.freeze({
      query: vi.fn(async () => {
        throw new Error("unexpected_direct_query");
      }),
    }) satisfies DatabaseTransaction;
    transactions.push(database);
    transactionOrdinals.set(database, ordinal);
    events.push(`transaction:${ordinal}:begin`);
    try {
      const result = await callback(database);
      events.push(`transaction:${ordinal}:commit`);
      return result;
    } catch (error) {
      events.push(`transaction:${ordinal}:rollback`);
      throw error;
    }
  };
  const storageCalls: unknown[][] = [];
  const createSignedUrl = vi.fn(
    async (bucket: string, path: string, expiresInSeconds: number) => {
      storageCalls.push([bucket, path, expiresInSeconds]);
      events.push("storage:create-signed-url");
      return options.signedUrl ??
        "https://cdn.example.test/storage/v1/object/sign/opaque-token";
    },
  );

  return {
    service: createPrivacyRequestService({
      claims: {
        userId: options.userId ?? userId,
        sessionId,
        aal: "aal2",
      },
      withMemberTransaction,
      repository,
      signedStorage: { createSignedUrl },
      ...(options.now === undefined ? {} : { now: options.now }),
    }),
    events,
    transactions,
    storageCalls,
    repository,
    list,
    requestExport,
    requestDeletion,
    getDeletionTombstone,
    prepareDownload,
    confirmDownload,
    createSignedUrl,
  };
}

describe("privacy request service", () => {
  it("hashes and subject-scopes export requests without exposing the client key", async () => {
    const clientKey = "same-client-key";
    const first = fixture();
    const second = fixture({ userId: otherUserId });

    await first.service.request("export", clientKey);
    await second.service.request("export", clientKey);

    const expectedFirst = `privacy-export:${await sha256TextHex(
      `${userId}\u0000${clientKey}`,
    )}`;
    const expectedSecond = `privacy-export:${await sha256TextHex(
      `${otherUserId}\u0000${clientKey}`,
    )}`;
    expect(first.requestExport).toHaveBeenCalledWith(expectedFirst);
    expect(second.requestExport).toHaveBeenCalledWith(expectedSecond);
    expect(expectedFirst).not.toBe(expectedSecond);
    expect(expectedFirst).not.toContain(clientKey);
    expect(first.events).toEqual([
      "transaction:1:begin",
      "transaction:1:repository-bound",
      "repository:request-export",
      "transaction:1:commit",
    ]);
  });

  it("hashes the deletion receipt and binds it to the verified session", async () => {
    const test = fixture();
    const receipt = "step-up-receipt-that-must-not-reach-the-database";

    await test.service.request("deletion", "delete-key", receipt);

    expect(test.requestDeletion).toHaveBeenCalledWith(
      await sha256TextHex(receipt),
      sessionId,
      "delete-key",
    );
    expect(test.requestDeletion.mock.calls.flat()).not.toContain(receipt);
  });

  it("fails deletion without a receipt before opening a transaction", async () => {
    const test = fixture();

    await expect(test.service.request("deletion", "delete-key")).rejects
      .toBeInstanceOf(RepositoryStepUpRequiredError);
    expect(test.repository).not.toHaveBeenCalled();
    expect(test.events).toEqual([]);
  });

  it("wraps ordinary repository calls in committed member transactions", async () => {
    const test = fixture();

    await expect(test.service.list()).resolves.toEqual([{ id: requestId }]);
    await expect(test.service.getDeletionTombstone()).resolves.toEqual({
      id: "tombstone-id",
    });

    expect(test.events).toEqual([
      "transaction:1:begin",
      "transaction:1:repository-bound",
      "repository:list",
      "transaction:1:commit",
      "transaction:2:begin",
      "transaction:2:repository-bound",
      "repository:get-deletion-tombstone",
      "transaction:2:commit",
    ]);
  });

  it("invokes signed Storage strictly between committed prepare and confirm transactions", async () => {
    const test = fixture();

    await test.service.createDownloadUrl(requestId);

    expect(test.events).toEqual([
      "transaction:1:begin",
      "transaction:1:repository-bound",
      "repository:prepare-download",
      "transaction:1:commit",
      "storage:create-signed-url",
      "transaction:2:begin",
      "transaction:2:repository-bound",
      "repository:confirm-download",
      "transaction:2:commit",
    ]);
    expect(test.storageCalls).toEqual([
      ["privacy-exports", `${userId}/export.zip`, 30],
    ]);
    expect(
      test.storageCalls.flat().some((argument) =>
        test.transactions.includes(argument as DatabaseTransaction)
      ),
    ).toBe(false);
  });

  it.each([
    ["empty", ""],
    ["whitespace", "   \t"],
    ["malformed", "not-a-url"],
    ["non-HTTPS", "http://cdn.example.test/signed"],
    ["username", "https://member@cdn.example.test/signed"],
    ["password", "https://member:secret@cdn.example.test/signed"],
    ["oversized", `https://cdn.example.test/${"a".repeat(4_097)}`],
  ])(
    "rejects a %s signed URL before confirmation",
    async (_name, signedUrl) => {
      const test = fixture({ signedUrl });

      await expect(test.service.createDownloadUrl(requestId)).rejects.toThrow(
        "storage_unavailable",
      );
      expect(test.createSignedUrl).toHaveBeenCalledOnce();
      expect(test.confirmDownload).not.toHaveBeenCalled();
      expect(test.events.at(-1)).toBe("storage:create-signed-url");
    },
  );

  it("rejects a Storage TTL above 30 seconds before signing or confirmation", async () => {
    const test = fixture({ expiresInSeconds: 31 });

    await expect(test.service.createDownloadUrl(requestId)).rejects.toThrow(
      "storage_unavailable",
    );
    expect(test.createSignedUrl).not.toHaveBeenCalled();
    expect(test.confirmDownload).not.toHaveBeenCalled();
    expect(test.events.at(-1)).toBe("transaction:1:commit");
  });

  it("propagates confirmation failure after Storage signing", async () => {
    const confirmError = new Error("confirmation_failed");
    const test = fixture({ confirmError });

    await expect(test.service.createDownloadUrl(requestId)).rejects.toBe(
      confirmError,
    );
    expect(test.createSignedUrl).toHaveBeenCalledOnce();
    expect(test.events).toEqual([
      "transaction:1:begin",
      "transaction:1:repository-bound",
      "repository:prepare-download",
      "transaction:1:commit",
      "storage:create-signed-url",
      "transaction:2:begin",
      "transaction:2:repository-bound",
      "repository:confirm-download",
      "transaction:2:rollback",
    ]);
  });

  it("derives deterministic expiry from the injected pre-signing clock", async () => {
    const now = vi.fn(() => Date.parse("2026-08-29T12:00:00.000Z"));
    const test = fixture({ now });

    await expect(test.service.createDownloadUrl(requestId)).resolves.toEqual({
      url: "https://cdn.example.test/storage/v1/object/sign/opaque-token",
      expires_at: "2026-08-29T12:00:30.000Z",
    });
    expect(now).toHaveBeenCalledOnce();
  });
});
