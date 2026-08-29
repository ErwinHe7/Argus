import type { VerifiedRequestClaims } from "../../db/request-claims.ts";
import { sha256TextHex } from "../../security/sha256.ts";
import type {
  WebullAuthorizationStarter,
  WebullReturnTarget,
  WithBrokerageConnectionRepository,
} from "./ports.ts";

const stateLifetimeMilliseconds = 5 * 60 * 1_000;
export const webullCompletionLifetimeMilliseconds = 5 * 60 * 1_000;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class BrokerageConnectionError extends Error {
  readonly code:
    | "connection_not_found"
    | "connection_already_connected"
    | "account_not_available"
    | "step_up_required"
    | "completion_not_found";

  constructor(code: BrokerageConnectionError["code"]) {
    super(code);
    this.name = "BrokerageConnectionError";
    this.code = code;
  }
}

export async function hashWebullOpaqueValue(value: string): Promise<string> {
  return sha256TextHex(value);
}

export function newWebullOpaqueValue(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function translateDisconnectDatabaseError(error: unknown): never {
  if (typeof error === "object" && error !== null) {
    const record = error as { code?: unknown; message?: unknown };
    if (record.code === "42501" && record.message === "step_up_required") {
      throw new BrokerageConnectionError("step_up_required");
    }
    if (
      record.code === "P0001" && record.message === "connection_not_found"
    ) {
      throw new BrokerageConnectionError("connection_not_found");
    }
  }
  throw error;
}

export function createBrokerageConnectionService(
  input: Readonly<{
    claims: VerifiedRequestClaims;
    authorization: WebullAuthorizationStarter;
    withRepository: WithBrokerageConnectionRepository;
    now?: () => Date;
  }>,
) {
  const now = input.now ?? (() => new Date());

  const start = async (
    returnTarget: WebullReturnTarget,
    reconnect: boolean,
  ) => {
    const state = newWebullOpaqueValue();
    // Provider contract validation intentionally precedes persistence, and the
    // provider redirect construction is never run inside a database transaction.
    const authorizationUrl = input.authorization.authorizationUrl(state);
    const stateHash = await hashWebullOpaqueValue(state);
    const startedAt = now();
    const expiresAt = new Date(startedAt.getTime() + stateLifetimeMilliseconds);
    const connectionId = await input.withRepository((repository) =>
      repository.start({
        sessionId: input.claims.sessionId,
        returnTarget,
        reconnect,
        stateHash,
        startedAt,
        expiresAt,
        contractVersion: input.authorization.contractVersion,
        environment: input.authorization.environment,
      })
    );
    return Object.freeze({
      connection_id: connectionId,
      authorization_url: authorizationUrl.toString(),
      expires_at: expiresAt.toISOString(),
    });
  };

  return Object.freeze({
    issueStepUp: async (action: "webull_disconnect" | "argus_delete") => {
      const receipt = newWebullOpaqueValue();
      const receiptHash = await hashWebullOpaqueValue(receipt);
      const expiresAt = new Date(now().getTime() + 5 * 60 * 1_000);
      await input.withRepository((repository) =>
        repository.issueStepUp({
          sessionId: input.claims.sessionId,
          action,
          receiptHash,
          aal: input.claims.aal,
          expiresAt,
        })
      );
      return Object.freeze({
        receipt,
        action,
        user_id: input.claims.userId,
        session_id: input.claims.sessionId,
        expires_at: expiresAt.toISOString(),
      });
    },
    start: (returnTarget: WebullReturnTarget) => start(returnTarget, false),
    reconnect: (returnTarget: WebullReturnTarget) => start(returnTarget, true),
    status: () => input.withRepository((repository) => repository.status()),
    selectAccount: (accountId: string) => {
      if (!uuidPattern.test(accountId)) {
        throw new BrokerageConnectionError("account_not_available");
      }
      return input.withRepository((repository) =>
        repository.selectAccount(accountId)
      );
    },
    redeemCompletion: async (handle: string) => {
      if (!/^[A-Za-z0-9_-]{43,128}$/.test(handle)) {
        throw new BrokerageConnectionError("completion_not_found");
      }
      const handleHash = await hashWebullOpaqueValue(handle);
      return input.withRepository((repository) =>
        repository.redeemCompletion(handleHash, input.claims.sessionId)
      );
    },
    disconnect: async (receipt: string) => {
      if (!/^[A-Za-z0-9_-]{32,512}$/.test(receipt)) {
        throw new BrokerageConnectionError("step_up_required");
      }
      const receiptHash = await hashWebullOpaqueValue(receipt);
      try {
        return await input.withRepository((repository) =>
          repository.disconnect(receiptHash, input.claims.sessionId)
        );
      } catch (error) {
        if (error instanceof BrokerageConnectionError) throw error;
        translateDisconnectDatabaseError(error);
      }
    },
  });
}

export type BrokerageConnectionService = ReturnType<
  typeof createBrokerageConnectionService
>;

export type {
  WebullAuthorizationStarter,
  WebullReturnTarget,
} from "./ports.ts";
