const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: false });

function owned(value: Uint8Array): Uint8Array<ArrayBuffer> {
  return new Uint8Array(value);
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value) || value.length % 4 !== 0) {
    throw new Error("invalid_webull_key_encoding");
  }
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function concat(...values: Uint8Array[]): Uint8Array {
  const length = values.reduce((total, value) => total + value.length, 0);
  const result = new Uint8Array(length);
  let offset = 0;
  for (const value of values) {
    result.set(value, offset);
    offset += value.length;
  }
  return result;
}

function splitCiphertext(value: ArrayBuffer): Readonly<{
  ciphertext: Uint8Array;
  tag: Uint8Array;
}> {
  const bytes = new Uint8Array(value);
  if (bytes.length <= 16) throw new Error("invalid_webull_ciphertext");
  return Object.freeze({
    ciphertext: bytes.slice(0, -16),
    tag: bytes.slice(-16),
  });
}

function aad(
  input: TokenOwnership,
  purpose: string,
  resourceVersion: number,
): Uint8Array {
  return encoder.encode([
    "argus-webull-aead-v1",
    input.environment,
    input.userId,
    input.connectionId,
    String(input.deletionEpoch),
    String(input.keyVersion),
    String(resourceVersion),
    purpose,
  ].join("\u001f"));
}

async function sha256Hex(value: Uint8Array): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", owned(value)),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function importAesKey(
  bytes: Uint8Array,
  extractable: boolean,
): Promise<CryptoKey> {
  if (bytes.length !== 32) throw new Error("invalid_webull_master_key_length");
  return crypto.subtle.importKey(
    "raw",
    owned(bytes),
    { name: "AES-GCM", length: 256 },
    extractable,
    ["encrypt", "decrypt"],
  );
}

async function encrypt(
  key: CryptoKey,
  plaintext: Uint8Array,
  associatedData: Uint8Array,
): Promise<
  Readonly<{ ciphertext: Uint8Array; nonce: Uint8Array; tag: Uint8Array }>
> {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const sealed = await crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv: owned(nonce),
      additionalData: owned(associatedData),
      tagLength: 128,
    },
    key,
    owned(plaintext),
  );
  return Object.freeze({ ...splitCiphertext(sealed), nonce });
}

async function decrypt(
  key: CryptoKey,
  ciphertext: Uint8Array,
  nonce: Uint8Array,
  tag: Uint8Array,
  associatedData: Uint8Array,
): Promise<Uint8Array> {
  if (nonce.length !== 12 || tag.length !== 16) {
    throw new Error("invalid_webull_ciphertext_shape");
  }
  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: owned(nonce),
      additionalData: owned(associatedData),
      tagLength: 128,
    },
    key,
    owned(concat(ciphertext, tag)),
  );
  return new Uint8Array(plaintext);
}

export type TokenOwnership = Readonly<{
  environment: "sandbox" | "production";
  userId: string;
  connectionId: string;
  deletionEpoch: number;
  keyVersion: number;
}>;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function validateOwnership(input: TokenOwnership): void {
  if (
    !uuidPattern.test(input.userId) ||
    !uuidPattern.test(input.connectionId) ||
    !Number.isSafeInteger(input.deletionEpoch) ||
    input.deletionEpoch < 0 ||
    !Number.isSafeInteger(input.keyVersion) ||
    input.keyVersion < 1
  ) {
    throw new Error("invalid_webull_token_ownership");
  }
}

export type ProtectedWebullCredentials =
  & TokenOwnership
  & Readonly<{
    tokenVersion: number;
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

export type PlainWebullCredentials = Readonly<{
  accessToken: string;
  refreshToken: string;
  accessExpiresAt: Date;
  refreshExpiresAt: Date;
}>;

export type WebullMasterKeyRing = Readonly<{
  activeVersion: number;
  keys: Readonly<Record<number, string>>;
}>;

export class WebullTokenVault {
  constructor(
    private readonly environment: "sandbox" | "production",
    private readonly keyRing: WebullMasterKeyRing,
  ) {
    if (
      !Number.isInteger(keyRing.activeVersion) ||
      keyRing.activeVersion < 1 ||
      keyRing.keys[keyRing.activeVersion] === undefined
    ) {
      throw new Error("invalid_webull_key_ring");
    }
  }

  private masterKeyBytes(version: number): Uint8Array {
    const encoded = this.keyRing.keys[version];
    if (encoded === undefined) throw new Error("missing_webull_key_version");
    const bytes = base64ToBytes(encoded);
    if (bytes.length !== 32) {
      throw new Error("invalid_webull_master_key_length");
    }
    return bytes;
  }

  async protectCredentials(
    input: Readonly<{
      userId: string;
      connectionId: string;
      deletionEpoch: number;
      tokenVersion: number;
      accessToken: string;
      refreshToken: string;
      accessExpiresAt: Date;
      refreshExpiresAt: Date;
    }>,
  ): Promise<ProtectedWebullCredentials> {
    if (
      input.accessToken.length < 8 ||
      input.refreshToken.length < 8 ||
      !Number.isInteger(input.tokenVersion) ||
      input.tokenVersion < 1 ||
      input.refreshExpiresAt <= input.accessExpiresAt
    ) {
      throw new Error("invalid_webull_credentials");
    }
    const ownership: TokenOwnership = Object.freeze({
      environment: this.environment,
      userId: input.userId,
      connectionId: input.connectionId,
      deletionEpoch: input.deletionEpoch,
      keyVersion: this.keyRing.activeVersion,
    });
    validateOwnership(ownership);
    if (
      !Number.isFinite(input.accessExpiresAt.getTime()) ||
      !Number.isFinite(input.refreshExpiresAt.getTime()) ||
      !Number.isSafeInteger(input.tokenVersion) ||
      input.tokenVersion < 1
    ) {
      throw new Error("invalid_webull_credential_versions");
    }
    const dataKeyBytes = crypto.getRandomValues(new Uint8Array(32));
    const dataKey = await importAesKey(dataKeyBytes, false);
    const masterKey = await importAesKey(
      this.masterKeyBytes(ownership.keyVersion),
      false,
    );
    const accessAad = aad(ownership, "access-token", input.tokenVersion);
    const refreshAad = aad(ownership, "refresh-token", input.tokenVersion);
    const wrappedAad = aad(ownership, "data-key", input.tokenVersion);
    const [access, refresh, wrapped, associatedDataHash] = await Promise.all([
      encrypt(dataKey, encoder.encode(input.accessToken), accessAad),
      encrypt(dataKey, encoder.encode(input.refreshToken), refreshAad),
      encrypt(masterKey, dataKeyBytes, wrappedAad),
      sha256Hex(concat(accessAad, refreshAad, wrappedAad)),
    ]);
    dataKeyBytes.fill(0);
    return Object.freeze({
      ...ownership,
      tokenVersion: input.tokenVersion,
      accessCiphertext: access.ciphertext,
      accessNonce: access.nonce,
      accessTag: access.tag,
      refreshCiphertext: refresh.ciphertext,
      refreshNonce: refresh.nonce,
      refreshTag: refresh.tag,
      wrappedDataKey: wrapped.ciphertext,
      wrappedKeyNonce: wrapped.nonce,
      wrappedKeyTag: wrapped.tag,
      associatedDataHash,
      accessExpiresAt: input.accessExpiresAt,
      refreshExpiresAt: input.refreshExpiresAt,
    });
  }

  async openCredentials(
    protectedValue: ProtectedWebullCredentials,
    expected: Omit<TokenOwnership, "keyVersion">,
  ): Promise<PlainWebullCredentials> {
    validateOwnership(protectedValue);
    if (
      !Number.isSafeInteger(protectedValue.tokenVersion) ||
      protectedValue.tokenVersion < 1
    ) {
      throw new Error("invalid_webull_token_version");
    }
    if (
      protectedValue.environment !== expected.environment ||
      protectedValue.userId !== expected.userId ||
      protectedValue.connectionId !== expected.connectionId ||
      protectedValue.deletionEpoch !== expected.deletionEpoch
    ) {
      throw new Error("webull_credential_owner_mismatch");
    }
    const ownership: TokenOwnership = protectedValue;
    const accessAad = aad(
      ownership,
      "access-token",
      protectedValue.tokenVersion,
    );
    const refreshAad = aad(
      ownership,
      "refresh-token",
      protectedValue.tokenVersion,
    );
    const wrappedAad = aad(ownership, "data-key", protectedValue.tokenVersion);
    if (
      await sha256Hex(concat(accessAad, refreshAad, wrappedAad)) !==
        protectedValue.associatedDataHash
    ) {
      throw new Error("webull_credential_aad_mismatch");
    }
    const masterKey = await importAesKey(
      this.masterKeyBytes(ownership.keyVersion),
      false,
    );
    const dataKeyBytes = await decrypt(
      masterKey,
      protectedValue.wrappedDataKey,
      protectedValue.wrappedKeyNonce,
      protectedValue.wrappedKeyTag,
      wrappedAad,
    );
    try {
      const dataKey = await importAesKey(dataKeyBytes, false);
      const [access, refresh] = await Promise.all([
        decrypt(
          dataKey,
          protectedValue.accessCiphertext,
          protectedValue.accessNonce,
          protectedValue.accessTag,
          accessAad,
        ),
        decrypt(
          dataKey,
          protectedValue.refreshCiphertext,
          protectedValue.refreshNonce,
          protectedValue.refreshTag,
          refreshAad,
        ),
      ]);
      return Object.freeze({
        accessToken: decoder.decode(access),
        refreshToken: decoder.decode(refresh),
        accessExpiresAt: protectedValue.accessExpiresAt,
        refreshExpiresAt: protectedValue.refreshExpiresAt,
      });
    } finally {
      dataKeyBytes.fill(0);
    }
  }

  async protectProviderIdentifier(
    ownership: Omit<TokenOwnership, "keyVersion">,
    resourceId: string,
    providerAccountId: string,
  ): Promise<Uint8Array> {
    if (!/^[\x21-\x7e]{1,512}$/.test(providerAccountId)) {
      throw new Error("invalid_webull_provider_account_id");
    }
    const full: TokenOwnership = {
      ...ownership,
      keyVersion: this.keyRing.activeVersion,
    };
    validateOwnership(full);
    if (!uuidPattern.test(resourceId)) {
      throw new Error("invalid_webull_account_resource_id");
    }
    const key = await importAesKey(this.masterKeyBytes(full.keyVersion), false);
    const sealed = await encrypt(
      key,
      encoder.encode(providerAccountId),
      aad(full, `account-id:${resourceId}`, 1),
    );
    return encoder.encode(JSON.stringify({
      v: 1,
      k: full.keyVersion,
      n: bytesToBase64(sealed.nonce),
      c: bytesToBase64(sealed.ciphertext),
      t: bytesToBase64(sealed.tag),
    }));
  }
}

export class WebullRefreshRejectedError extends Error {}

export interface WebullRefreshLeaseStore {
  acquire(
    input: Readonly<{
      connectionId: string;
      expectedTokenVersion: number;
      leaseToken: string;
      leasedUntil: Date;
    }>,
  ): Promise<boolean>;
  read(connectionId: string): Promise<ProtectedWebullCredentials>;
  compareAndSwap(
    input: Readonly<{
      expectedTokenVersion: number;
      next: ProtectedWebullCredentials;
    }>,
  ): Promise<boolean>;
  markReauthorizationRequired(
    connectionId: string,
    reason: string,
  ): Promise<void>;
  release(connectionId: string, leaseToken: string): Promise<void>;
}

export interface WebullRefreshProvider {
  refresh(
    refreshToken: string,
    rateLimitOwnerScope: string,
  ): Promise<PlainWebullCredentials>;
}

export async function rotateWebullCredentials(
  input: Readonly<{
    current: ProtectedWebullCredentials;
    vault: WebullTokenVault;
    store: WebullRefreshLeaseStore;
    provider: WebullRefreshProvider;
    now: Date;
  }>,
): Promise<
  Readonly<{
    outcome:
      | "rotated"
      | "won_elsewhere"
      | "refresh_in_progress"
      | "reauthorization_required";
    credentials?: ProtectedWebullCredentials;
  }>
> {
  const leaseToken = crypto.randomUUID();
  const acquired = await input.store.acquire({
    connectionId: input.current.connectionId,
    expectedTokenVersion: input.current.tokenVersion,
    leaseToken,
    leasedUntil: new Date(input.now.getTime() + 30_000),
  });
  if (!acquired) {
    const observed = await input.store.read(input.current.connectionId);
    if (observed.tokenVersion <= input.current.tokenVersion) {
      return Object.freeze({ outcome: "refresh_in_progress" });
    }
    return Object.freeze({
      outcome: "won_elsewhere",
      credentials: observed,
    });
  }

  try {
    const plain = await input.vault.openCredentials(input.current, {
      environment: input.current.environment,
      userId: input.current.userId,
      connectionId: input.current.connectionId,
      deletionEpoch: input.current.deletionEpoch,
    });
    let refreshed: PlainWebullCredentials;
    try {
      refreshed = await input.provider.refresh(
        plain.refreshToken,
        await sha256Hex(encoder.encode(input.current.userId)),
      );
    } catch (error) {
      const reason = error instanceof WebullRefreshRejectedError
        ? "refresh_rejected"
        : "refresh_outcome_unknown";
      await input.store.markReauthorizationRequired(
        input.current.connectionId,
        reason,
      );
      return Object.freeze({ outcome: "reauthorization_required" });
    }
    const next = await input.vault.protectCredentials({
      userId: input.current.userId,
      connectionId: input.current.connectionId,
      deletionEpoch: input.current.deletionEpoch,
      tokenVersion: input.current.tokenVersion + 1,
      ...refreshed,
    });
    if (
      !(await input.store.compareAndSwap({
        expectedTokenVersion: input.current.tokenVersion,
        next,
      }))
    ) {
      return Object.freeze({
        outcome: "won_elsewhere",
        credentials: await input.store.read(input.current.connectionId),
      });
    }
    return Object.freeze({ outcome: "rotated", credentials: next });
  } finally {
    await input.store.release(input.current.connectionId, leaseToken);
  }
}

export function parseWebullMasterKeyRing(value: string): WebullMasterKeyRing {
  const parsed = JSON.parse(value) as unknown;
  if (
    typeof parsed !== "object" ||
    parsed === null ||
    !("activeVersion" in parsed) ||
    !("keys" in parsed) ||
    typeof parsed.activeVersion !== "number" ||
    typeof parsed.keys !== "object" ||
    parsed.keys === null
  ) {
    throw new Error("invalid_webull_key_ring");
  }
  const keys = Object.fromEntries(
    Object.entries(parsed.keys).map(([key, entry]) => {
      if (
        !/^\d+$/.test(key) ||
        key !== String(Number(key)) ||
        typeof entry !== "string"
      ) {
        throw new Error("invalid_webull_key_ring");
      }
      return [Number(key), entry];
    }),
  );
  return Object.freeze({ activeVersion: parsed.activeVersion, keys });
}
