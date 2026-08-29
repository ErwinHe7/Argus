import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it, vi } from "vitest";

import {
  normalizeAccount,
  normalizeRestriction,
} from "../../src/domains/brokerage-accounts/normalization.ts";
import {
  type BrokerageProjectionProvider,
  createBrokerageProjectionService
    as createProductionBrokerageProjectionService,
} from "../../src/domains/brokerage-projections/service.ts";
import {
  parseBrokerageSafeInteger,
} from "../../src/domains/brokerage-projections/repository.ts";
import type { BrokerageProjectionRepository } from "../../src/domains/brokerage-projections/ports.ts";
import { BrokerageProjectionError } from "../../src/domains/brokerage-projections/types.ts";

const fixture = JSON.parse(
  await readFile(
    resolve(
      dirname(fileURLToPath(import.meta.url)),
      "../fixtures/webull/reads.v1.json",
    ),
    "utf8",
  ),
) as Record<string, unknown>;
const accountId = "018f3c2a-4b67-7a89-8abc-123456789010";

function createBrokerageProjectionService(
  input:
    & Omit<
      Parameters<typeof createProductionBrokerageProjectionService>[0],
      "withRepository"
    >
    & { repository: BrokerageProjectionRepository },
) {
  const { repository, ...serviceInput } = input;
  return createProductionBrokerageProjectionService({
    ...serviceInput,
    withRepository: (callback) => callback(repository),
  });
}

describe("brokerage account authority", () => {
  it("preserves multiple accounts and one active selection", async () => {
    const accounts = [
      { id: accountId, display_label: "Webull •••• 0001", selected: true },
      {
        id: "018f3c2a-4b67-7a89-8abc-123456789011",
        display_label: "Webull •••• 0002",
        selected: false,
      },
    ];
    const repository = {
      listAccounts: vi.fn(async () => accounts),
    } as unknown as BrokerageProjectionRepository;
    const service = createBrokerageProjectionService({
      repository,
      provider: {} as BrokerageProjectionProvider,
    });
    await expect(service.listAccounts()).resolves.toEqual(accounts);
    expect((await service.listAccounts()).filter((entry) => entry.selected))
      .toHaveLength(1);
  });

  it("fails account IDOR before provider access", async () => {
    const provider = { read: vi.fn() };
    const repository = {
      account: vi.fn(async () => {
        throw new BrokerageProjectionError("account_not_found");
      }),
    } as unknown as BrokerageProjectionRepository;
    const service = createBrokerageProjectionService({ repository, provider });
    await expect(
      service.read("018f3c2a-4b67-7a89-8abc-123456789099", "balance"),
    ).rejects.toThrow("account_not_found");
    expect(provider.read).not.toHaveBeenCalled();
  });

  it("does not turn unknown capabilities or restrictions into supported behavior", () => {
    const normalized = normalizeAccount(fixture.account);
    expect(normalized.capabilities).toContainEqual({
      capability: "unsupported",
      provider_code: "FUTURE_PROVIDER_CAPABILITY",
      available: false,
    });
    expect(
      normalizeRestriction((fixture.restrictions as unknown[])[1]),
    ).toMatchObject({
      restriction: "unsupported",
      provider_code: "FUTURE_PROVIDER_RESTRICTION",
      active: true,
    });
  });

  it("rejects unsafe bigint generations and capability versions", () => {
    expect(() => parseBrokerageSafeInteger("9007199254740992", "generation", 1))
      .toThrow("invalid_generation");
    expect(() => parseBrokerageSafeInteger(-1, "capability_version")).toThrow(
      "invalid_capability_version",
    );
    expect(parseBrokerageSafeInteger("7", "capability_version")).toBe(7);
  });

  it("rejects control and bidirectional override characters in member-visible text", () => {
    expect(() =>
      normalizeAccount({
        ...(fixture.account as Record<string, unknown>),
        display_label: "Webull\u202e1000",
      })
    ).toThrow("invalid_provider_account");
    expect(() =>
      normalizeRestriction({
        code: "CLOSING_ONLY",
        active: true,
        detail: "hidden\u0000suffix",
      })
    ).toThrow("invalid_provider_restriction");
  });
});
