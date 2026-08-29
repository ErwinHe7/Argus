export type WebullReturnTarget = "webull_https" | "webull_native";

export interface WebullAuthorizationStarter {
  readonly contractVersion: string;
  readonly environment: "sandbox" | "production";
  authorizationUrl(state: string): URL;
}

export type ConsumedWebullState = Readonly<{
  stateId: string;
  userId: string;
  sessionId: string;
  deletionEpoch: number;
  connectionId: string;
  returnTarget: WebullReturnTarget;
  contractVersion: string;
  environment: "sandbox" | "production";
}>;

export type ProtectedCallbackCredentials = Readonly<{
  environment: "sandbox" | "production";
  userId: string;
  connectionId: string;
  deletionEpoch: number;
  tokenVersion: number;
  keyVersion: number;
  accessCiphertext: Uint8Array;
  accessNonce: Uint8Array;
  accessTag: Uint8Array;
  refreshCiphertext: Uint8Array;
  refreshNonce: Uint8Array;
  refreshTag: Uint8Array;
  wrappedDataKey: Uint8Array;
  wrappedKeyNonce: Uint8Array;
  wrappedKeyTag: Uint8Array;
  associatedDataHash: string;
  accessExpiresAt: Date;
  refreshExpiresAt: Date;
}>;

export type ProtectedCallbackAccount = Readonly<{
  id: string;
  displayLabel: string;
  baseCurrency: string;
  status: "available" | "restricted" | "closed" | "unavailable";
  capabilityVersion: number;
  marketTimezone: string;
  capabilities: readonly unknown[];
  fetchedAt: Date;
  expiresAt: Date;
  providerIdCiphertext: Uint8Array;
  providerIdHash: string;
  keyVersion: number;
  userId: string;
  connectionId: string;
  deletionEpoch: number;
}>;

export interface BrokerageConnectionRepository {
  issueStepUp(
    input: Readonly<{
      sessionId: string;
      action: "webull_disconnect" | "argus_delete";
      receiptHash: string;
      aal: "aal1" | "aal2";
      expiresAt: Date;
    }>,
  ): Promise<void>;
  start(
    input: Readonly<{
      sessionId: string;
      returnTarget: WebullReturnTarget;
      reconnect: boolean;
      stateHash: string;
      startedAt: Date;
      expiresAt: Date;
      contractVersion: string;
      environment: "sandbox" | "production";
    }>,
  ): Promise<string>;
  status(): Promise<Record<string, unknown>>;
  selectAccount(accountId: string): Promise<
    Readonly<{
      account_id: string;
      selected: true;
    }>
  >;
  redeemCompletion(
    handleHash: string,
    sessionId: string,
  ): Promise<Record<string, unknown>>;
  disconnect(
    receiptHash: string,
    sessionId: string,
  ): Promise<
    Readonly<{
      connection_id: string;
      status: "disconnected";
      provider_grant_revoked: boolean;
    }>
  >;
}

export type WithBrokerageConnectionRepository = <T>(
  callback: (repository: BrokerageConnectionRepository) => Promise<T>,
) => Promise<T>;

export interface WebullCallbackRepository {
  consumeState(
    stateHash: string,
    consumedAt: Date,
  ): Promise<ConsumedWebullState | null>;
  complete(
    state: ConsumedWebullState,
    credentials: ProtectedCallbackCredentials,
    accounts: readonly ProtectedCallbackAccount[],
    handleHash: string,
    expiresAt: Date,
  ): Promise<void>;
  fail(
    state: ConsumedWebullState,
    outcome: "denied" | "failed" | "temporarily_unavailable",
    handleHash: string,
    expiresAt: Date,
  ): Promise<void>;
}

export type WebullCallbackClaims = Readonly<{
  userId: string;
  sessionId: string;
  aal: "aal1";
}>;

export type WithWebullCallbackRepository = <T>(
  claims: WebullCallbackClaims | null,
  callback: (repository: WebullCallbackRepository) => Promise<T>,
) => Promise<T>;
