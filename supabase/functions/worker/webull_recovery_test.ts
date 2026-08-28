import {
  assertEquals,
  assertRejects,
} from "jsr:@std/assert@1.0.15";

import type { DatabaseClient } from "../../../ritual-investing-api/src/db/database-port.ts";
import {
  createWebullRecoveryPorts,
  WebullRecoveryBeforeEgressError,
  type WebullRecoveryProvider,
} from "../_shared/jobs/webull-recovery.ts";
import { WebullTokenVault } from "../_shared/webull/tokens.ts";

const userId = "018f3c2a-4b67-7a89-8abc-123456789001";
const connectionId = "018f3c2a-4b67-7a89-8abc-123456789002";
const accountId = "018f3c2a-4b67-7a89-8abc-123456789003";
const eventId = "018f3c2a-4b67-7a89-8abc-123456789004";
const commandId = "018f3c2a-4b67-7a89-8abc-123456789005";
const leaseId = "018f3c2a-4b67-7a89-8abc-123456789006";
const now = new Date("2026-08-28T12:00:00.000Z");

function key(byte: number): string {
  return btoa(String.fromCharCode(...new Uint8Array(32).fill(byte)));
}

const vault = new WebullTokenVault("sandbox", {
  activeVersion: 2,
  keys: { 1: key(1), 2: key(2) },
});

async function fixtureCredentials() {
  const protectedValue = await vault.protectCredentials({
    userId,
    connectionId,
    deletionEpoch: 3,
    tokenVersion: 7,
    accessToken: "access-token-current",
    refreshToken: "refresh-token-current",
    accessExpiresAt: new Date(now.getTime() + 60_000),
    refreshExpiresAt: new Date(now.getTime() + 86_400_000),
  });
  return {
    user_id: protectedValue.userId,
    deletion_epoch: protectedValue.deletionEpoch,
    connection_id: protectedValue.connectionId,
    provider_environment: protectedValue.environment,
    token_version: protectedValue.tokenVersion,
    key_version: protectedValue.keyVersion,
    access_ciphertext: protectedValue.accessCiphertext,
    access_nonce: protectedValue.accessNonce,
    access_tag: protectedValue.accessTag,
    refresh_ciphertext: protectedValue.refreshCiphertext,
    refresh_nonce: protectedValue.refreshNonce,
    refresh_tag: protectedValue.refreshTag,
    wrapped_data_key: protectedValue.wrappedDataKey,
    wrapped_key_nonce: protectedValue.wrappedKeyNonce,
    wrapped_key_tag: protectedValue.wrappedKeyTag,
    associated_data_hash: protectedValue.associatedDataHash,
    access_expires_at: protectedValue.accessExpiresAt,
    refresh_expires_at: protectedValue.refreshExpiresAt,
  };
}

function transaction(
  query: (sql: string, values: readonly unknown[]) => Promise<readonly unknown[]>,
) {
  return async <T>(callback: (database: DatabaseClient) => Promise<T>) =>
    callback({
      async query<Row>(sql: string, values: readonly unknown[] = []) {
        return { rows: [...await query(sql, values)] as Row[] };
      },
      release() {},
    });
}

function provider(overrides: Partial<WebullRecoveryProvider>): WebullRecoveryProvider {
  const unavailable = async (): Promise<never> => {
    throw new Error("unexpected_provider_call");
  };
  return {
    refresh: overrides.refresh ?? unavailable,
    readProjection: overrides.readProjection ?? unavailable,
    lookupExistingCommand: overrides.lookupExistingCommand ?? unavailable,
  };
}

Deno.test("token refresh records egress before provider and CAS persistence", async () => {
  const credential = await fixtureCredentials();
  const calls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql, values) => {
      if (sql.includes("claim_webull_token_refresh")) return [{ claim_outcome: "claimed", ...credential }];
      if (sql.includes("mark_webull_refresh_egress_started")) {
        calls.push("egress");
        return [{ allowed: true }];
      }
      if (sql.includes("commit_webull_token_refresh")) {
        calls.push("commit");
        assertEquals(values[2], 7);
        assertEquals(values[3], 2);
        assertEquals(values[4], credential.associated_data_hash);
        assertEquals(values[6], 8);
        return [{ committed: true }];
      }
      return [];
    }),
    provider: provider({
      refresh: async (token) => {
        calls.push("provider");
        assertEquals(token, "refresh-token-current");
        return {
          accessToken: "access-token-next",
          refreshToken: "refresh-token-next",
          accessExpiresAt: new Date(now.getTime() + 120_000),
          refreshExpiresAt: new Date(now.getTime() + 172_800_000),
        };
      },
    }),
  });
  assertEquals(await ports.tokenRefresh.refreshExistingConnection({
    eventId,
    connectionId,
    keepAlive: async () => {
      calls.push("keepalive");
    },
  }), "rotated");
  assertEquals(calls, ["keepalive", "egress", "provider", "keepalive", "commit"]);
});

Deno.test("unknown refresh response is fenced and the old token is never retried", async () => {
  const credential = await fixtureCredentials();
  let providerCalls = 0;
  const sqlCalls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      sqlCalls.push(sql);
      if (sql.includes("claim_webull_token_refresh")) return [{ claim_outcome: "claimed", ...credential }];
      if (sql.includes("mark_webull_refresh_egress_started")) return [{ allowed: true }];
      return [];
    }),
    provider: provider({
      refresh: async () => {
        providerCalls += 1;
        throw new Error("lost_response");
      },
    }),
  });
  assertEquals(await ports.tokenRefresh.refreshExistingConnection({
    eventId,
    connectionId,
    keepAlive: async () => undefined,
  }), "reauthorization_required");
  assertEquals(providerCalls, 1);
  assertEquals(sqlCalls.some((sql) => sql.includes("fence_webull_refresh_outcome")), true);
  assertEquals(sqlCalls.some((sql) => sql.includes("commit_webull_token_refresh")), false);
});

Deno.test("a rejected post-response refresh CAS destroys the old credential", async () => {
  const credential = await fixtureCredentials();
  const sqlCalls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      sqlCalls.push(sql);
      if (sql.includes("claim_webull_token_refresh")) {
        return [{ claim_outcome: "claimed", ...credential }];
      }
      if (sql.includes("mark_webull_refresh_egress_started")) {
        return [{ allowed: true }];
      }
      if (sql.includes("commit_webull_token_refresh")) {
        return [{ committed: false }];
      }
      if (sql.includes("fence_webull_refresh_outcome")) {
        return [{ fenced: true }];
      }
      return [];
    }),
    provider: provider({
      refresh: async () => ({
        accessToken: "access-token-next",
        refreshToken: "refresh-token-next",
        accessExpiresAt: new Date(now.getTime() + 120_000),
        refreshExpiresAt: new Date(now.getTime() + 172_800_000),
      }),
    }),
  });
  assertEquals(await ports.tokenRefresh.refreshExistingConnection({
    eventId,
    connectionId,
    keepAlive: async () => undefined,
  }), "reauthorization_required");
  assertEquals(sqlCalls.some((sql) =>
    sql.includes("refresh_outcome_unknown") &&
    sql.includes("fence_webull_refresh_outcome")
  ), true);
});

Deno.test("proved before-egress failure resets the marker and remains retryable", async () => {
  const credential = await fixtureCredentials();
  const sqlCalls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      sqlCalls.push(sql);
      if (sql.includes("claim_webull_token_refresh")) return [{ claim_outcome: "claimed", ...credential }];
      if (sql.includes("mark_webull_refresh_egress_started")) return [{ allowed: true }];
      return [];
    }),
    provider: provider({
      refresh: async () => {
        throw new WebullRecoveryBeforeEgressError();
      },
    }),
  });
  await assertRejects(() => ports.tokenRefresh.refreshExistingConnection({
    eventId,
    connectionId,
    keepAlive: async () => undefined,
  }), Error, "dependency_unavailable");
  assertEquals(sqlCalls.some((sql) => sql.includes("reset_webull_refresh_before_egress")), true);
  assertEquals(sqlCalls.some((sql) => sql.includes("release_webull_token_refresh")), true);
});

Deno.test("token refresh denied after decrypt never reaches the provider", async () => {
  const credential = await fixtureCredentials();
  const calls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      if (sql.includes("claim_webull_token_refresh")) {
        calls.push("claim");
        return [{ claim_outcome: "claimed", ...credential }];
      }
      if (sql.includes("mark_webull_refresh_egress_started")) {
        calls.push("gate");
        return [{ allowed: false }];
      }
      return [];
    }),
    provider: provider({
      refresh: async () => {
        calls.push("provider");
        throw new Error("provider_must_not_be_called");
      },
    }),
  });
  await assertRejects(() => ports.tokenRefresh.refreshExistingConnection({
    eventId,
    connectionId,
    keepAlive: async () => {
      calls.push("keepalive");
    },
  }), Error, "deletion_epoch_changed");
  assertEquals(calls, ["claim", "keepalive", "gate"]);
});

Deno.test("reconciliation sends only existing lookup identifiers and bounds not-found", async () => {
  const credential = await fixtureCredentials();
  const providerAccount = await vault.protectProviderIdentifier({
    environment: "sandbox",
    userId,
    connectionId,
    deletionEpoch: 3,
  }, accountId, "provider-account-canary");
  let lookupKeys: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      if (sql.includes("claim_webull_command_reconciliation")) return [{
        claim_outcome: "claimed",
        ...credential,
        command_id: commandId,
        account_id: accountId,
        operation: "place",
        client_order_id: "argus_existing_client_order",
        target_order_id: null,
        provider_account_id_ciphertext: providerAccount,
        provider_account_key_version: 2,
        target_order_ref_ciphertext: null,
        target_order_ref_key_version: null,
      }];
      if (sql.includes("authorize_webull_reconciliation_egress")) return [{ allowed: true }];
      if (sql.includes("record_webull_reconciliation_retry")) return [{ outcome: "manual_review" }];
      return [];
    }),
    provider: provider({
      lookupExistingCommand: async (input) => {
        lookupKeys = Object.keys(input).sort();
        return { kind: "not_found" };
      },
    }),
  });
  assertEquals(await ports.reconciliation.inspectExistingCommand({
    eventId,
    commandId,
    keepAlive: async () => undefined,
  }), "manual_review");
  assertEquals(lookupKeys, [
    "accessToken",
    "clientOrderId",
    "operation",
    "providerAccountId",
    "targetOrderReference",
  ]);
});

Deno.test("fifth reconciliation delivery terminalizes before provider lookup", async () => {
  let providerCalls = 0;
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) =>
      sql.includes("claim_webull_command_reconciliation")
        ? [{ claim_outcome: "manual_review" }]
        : []),
    provider: provider({
      lookupExistingCommand: async () => {
        providerCalls += 1;
        return { kind: "not_found" };
      },
    }),
  });
  assertEquals(await ports.reconciliation.inspectExistingCommand({
    eventId,
    commandId,
    keepAlive: async () => undefined,
  }), "manual_review");
  assertEquals(providerCalls, 0);
});

Deno.test("reconciliation denied after decrypt never reaches the provider", async () => {
  const credential = await fixtureCredentials();
  const providerAccount = await vault.protectProviderIdentifier({
    environment: "sandbox",
    userId,
    connectionId,
    deletionEpoch: 3,
  }, accountId, "provider-account-canary");
  const calls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      if (sql.includes("claim_webull_command_reconciliation")) {
        calls.push("claim");
        return [{
          claim_outcome: "claimed",
          ...credential,
          command_id: commandId,
          account_id: accountId,
          operation: "place",
          client_order_id: "argus_existing_client_order",
          target_order_id: null,
          provider_account_id_ciphertext: providerAccount,
          provider_account_key_version: 2,
          target_order_ref_ciphertext: null,
          target_order_ref_key_version: null,
        }];
      }
      if (sql.includes("authorize_webull_reconciliation_egress")) {
        calls.push("gate");
        return [{ allowed: false }];
      }
      return [];
    }),
    provider: provider({
      lookupExistingCommand: async () => {
        calls.push("provider");
        throw new Error("provider_must_not_be_called");
      },
    }),
  });
  await assertRejects(() => ports.reconciliation.inspectExistingCommand({
    eventId,
    commandId,
    keepAlive: async () => {
      calls.push("keepalive");
    },
  }), Error, "deletion_epoch_changed");
  assertEquals(calls, ["claim", "keepalive", "gate"]);
});

Deno.test("a lost positive reconciliation commit converges to manual review", async () => {
  const credential = await fixtureCredentials();
  const providerAccount = await vault.protectProviderIdentifier({
    environment: "sandbox",
    userId,
    connectionId,
    deletionEpoch: 3,
  }, accountId, "provider-account-canary");
  const sqlCalls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      sqlCalls.push(sql);
      if (sql.includes("claim_webull_command_reconciliation")) return [{
        claim_outcome: "claimed",
        ...credential,
        command_id: commandId,
        account_id: accountId,
        operation: "place",
        client_order_id: "argus_existing_client_order",
        target_order_id: null,
        provider_account_id_ciphertext: providerAccount,
        provider_account_key_version: 2,
        target_order_ref_ciphertext: null,
        target_order_ref_key_version: null,
      }];
      if (sql.includes("authorize_webull_reconciliation_egress")) {
        return [{ allowed: true }];
      }
      if (sql.includes("commit_webull_reconciliation")) {
        return [{ committed: false }];
      }
      return [];
    }),
    provider: provider({
      lookupExistingCommand: async () => ({
        kind: "resolved",
        resolution: "applied",
        providerOrderReference: "provider-order-canary",
        order: {
          id: leaseId,
          instrument_id: "018f3c2a-4b67-7a89-8abc-123456789007",
          symbol: "ARGX",
          side: "buy",
          provider_side: "BUY",
          order_type: "limit",
          provider_order_type: "LIMIT",
          time_in_force: "day",
          provider_time_in_force: "DAY",
          quantity: "1",
          filled_quantity: "0",
          limit_price: "10",
          stop_price: null,
          average_fill_price: null,
          currency: "USD",
          state: "pending",
          provider_state: "PENDING",
          terminal: false,
          generation: 1,
          source: "detail",
          provider_observed_at: now.toISOString(),
          fetched_at: now.toISOString(),
        },
      }),
    }),
  });
  assertEquals(await ports.reconciliation.inspectExistingCommand({
    eventId,
    commandId,
    keepAlive: async () => undefined,
  }), "manual_review");
  assertEquals(sqlCalls.some((sql) =>
    sql.includes("terminalize_webull_recovery_dead_letter")
  ), true);
});

Deno.test("projection transient recovery preserves its opaque lease", async () => {
  const credential = await fixtureCredentials();
  const providerAccount = await vault.protectProviderIdentifier({
    environment: "sandbox",
    userId,
    connectionId,
    deletionEpoch: 3,
  }, accountId, "provider-account-canary");
  let preserve = false;
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql, values) => {
      if (sql.includes("claim_webull_projection_refresh")) return [{
        claim_outcome: "claimed",
        ...credential,
        lease_id: leaseId,
        account_id: accountId,
        resource_type: "balance",
        provider_account_id_ciphertext: providerAccount,
        provider_account_key_version: 2,
      }];
      if (sql.includes("authorize_webull_projection_egress")) return [{ allowed: true }];
      if (sql.includes("release_webull_projection_refresh")) preserve = values[3] === true;
      return [];
    }),
    provider: provider({
      readProjection: async () => {
        throw new Error("timeout");
      },
    }),
  });
  await assertRejects(() => ports.projectionRefresh.refreshExistingProjection({
    eventId,
    leaseId,
    keepAlive: async () => undefined,
  }), Error, "dependency_unavailable");
  assertEquals(preserve, true);
});

Deno.test("projection refresh denied after decrypt never reaches the provider", async () => {
  const credential = await fixtureCredentials();
  const providerAccount = await vault.protectProviderIdentifier({
    environment: "sandbox",
    userId,
    connectionId,
    deletionEpoch: 3,
  }, accountId, "provider-account-canary");
  const calls: string[] = [];
  const ports = createWebullRecoveryPorts({
    vault,
    now: () => now,
    transaction: transaction(async (sql) => {
      if (sql.includes("claim_webull_projection_refresh")) {
        calls.push("claim");
        return [{
          claim_outcome: "claimed",
          ...credential,
          lease_id: leaseId,
          account_id: accountId,
          resource_type: "balance",
          provider_account_id_ciphertext: providerAccount,
          provider_account_key_version: 2,
        }];
      }
      if (sql.includes("authorize_webull_projection_egress")) {
        calls.push("gate");
        return [{ allowed: false }];
      }
      return [];
    }),
    provider: provider({
      readProjection: async () => {
        calls.push("provider");
        throw new Error("provider_must_not_be_called");
      },
    }),
  });
  await assertRejects(() => ports.projectionRefresh.refreshExistingProjection({
    eventId,
    leaseId,
    keepAlive: async () => {
      calls.push("keepalive");
    },
  }), Error, "deletion_epoch_changed");
  assertEquals(calls, ["claim", "keepalive", "gate"]);
});
