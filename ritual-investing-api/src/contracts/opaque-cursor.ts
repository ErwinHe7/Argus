import { sha256TextHex } from "../security/sha256.ts";

export type CursorPositionValue = string | number | boolean | null;
export type CursorPosition = readonly CursorPositionValue[];

export interface OpaqueCursorBinding {
  resource: string;
  scope: string;
  verifiedSubject: string;
  filterIdentity: string;
  pageSize: number;
}

export interface OpaqueCursorInput extends OpaqueCursorBinding {
  position: CursorPosition;
}

interface CursorEnvelopeV1 {
  v: 1;
  r: string;
  b: string;
  n: number;
  p: CursorPosition;
}

export const OPAQUE_CURSOR_VERSION = 1 as const;
export const MAX_OPAQUE_CURSOR_LENGTH = 2_048;

const MAX_RESOURCE_LENGTH = 128;
const MAX_SCOPE_LENGTH = 128;
const MAX_SUBJECT_LENGTH = 256;
const MAX_FILTER_IDENTITY_LENGTH = 512;
const MAX_PAGE_SIZE = 1_000;
const MAX_POSITION_VALUES = 8;
const MAX_POSITION_STRING_LENGTH = 512;

const envelopeKeys = ["v", "r", "b", "n", "p"] as const;
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder("utf-8", { fatal: true });

export class InvalidOpaqueCursorError extends Error {
  constructor() {
    super("invalid_cursor");
    this.name = "InvalidOpaqueCursorError";
  }
}

function invalidCursor(): never {
  throw new InvalidOpaqueCursorError();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isBoundedString(
  value: unknown,
  maximumLength: number,
): value is string {
  return typeof value === "string" && value.length > 0 &&
    value.length <= maximumLength;
}

function isPositionValue(value: unknown): value is CursorPositionValue {
  return value === null ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isSafeInteger(value)) ||
    isBoundedString(value, MAX_POSITION_STRING_LENGTH);
}

function parseEnvelope(value: unknown): CursorEnvelopeV1 {
  if (!isRecord(value)) invalidCursor();

  const keys = Object.keys(value);
  if (
    keys.length !== envelopeKeys.length ||
    envelopeKeys.some((key) => !Object.hasOwn(value, key))
  ) {
    invalidCursor();
  }

  if (
    value.v !== OPAQUE_CURSOR_VERSION ||
    !isBoundedString(value.r, MAX_RESOURCE_LENGTH) ||
    typeof value.b !== "string" ||
    !/^[a-f0-9]{64}$/.test(value.b) ||
    typeof value.n !== "number" ||
    !Number.isInteger(value.n) ||
    value.n < 1 ||
    value.n > MAX_PAGE_SIZE ||
    !Array.isArray(value.p) ||
    value.p.length < 1 ||
    value.p.length > MAX_POSITION_VALUES ||
    !value.p.every(isPositionValue)
  ) {
    invalidCursor();
  }

  return {
    v: OPAQUE_CURSOR_VERSION,
    r: value.r,
    b: value.b,
    n: value.n,
    p: [...value.p],
  };
}

function assertBinding(input: OpaqueCursorBinding): void {
  if (
    !isBoundedString(input.resource, MAX_RESOURCE_LENGTH) ||
    !isBoundedString(input.scope, MAX_SCOPE_LENGTH) ||
    !isBoundedString(input.verifiedSubject, MAX_SUBJECT_LENGTH) ||
    !isBoundedString(input.filterIdentity, MAX_FILTER_IDENTITY_LENGTH) ||
    !Number.isInteger(input.pageSize) ||
    input.pageSize < 1 ||
    input.pageSize > MAX_PAGE_SIZE
  ) {
    invalidCursor();
  }
}

async function bindingDigest(input: OpaqueCursorBinding): Promise<string> {
  assertBinding(input);
  const fields = [
    input.resource,
    input.scope,
    input.verifiedSubject,
    input.filterIdentity,
    String(input.pageSize),
  ];
  const canonical = fields.map((field) => `${field.length}:${field}`).join("|");
  return sha256TextHex(canonical);
}

function encodeBase64Url(value: string): string {
  const bytes = textEncoder.encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function decodeBase64Url(value: string): string {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) invalidCursor();
  const base64 = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return textDecoder.decode(bytes);
}

export async function encodeOpaqueCursor(
  input: OpaqueCursorInput,
): Promise<string> {
  const envelope = parseEnvelope({
    v: OPAQUE_CURSOR_VERSION,
    r: input.resource,
    b: await bindingDigest(input),
    n: input.pageSize,
    p: [...input.position],
  });
  const cursor = encodeBase64Url(JSON.stringify(envelope));
  if (cursor.length > MAX_OPAQUE_CURSOR_LENGTH) invalidCursor();
  return cursor;
}

export async function decodeOpaqueCursor(
  cursor: string,
  expected: OpaqueCursorBinding,
): Promise<CursorPosition> {
  if (
    typeof cursor !== "string" ||
    cursor.length < 1 ||
    cursor.length > MAX_OPAQUE_CURSOR_LENGTH
  ) {
    invalidCursor();
  }

  try {
    const decoded = decodeBase64Url(cursor);
    if (encodeBase64Url(decoded) !== cursor) invalidCursor();
    const envelope = parseEnvelope(JSON.parse(decoded));
    if (
      envelope.r !== expected.resource ||
      envelope.b !== await bindingDigest(expected) ||
      envelope.n !== expected.pageSize
    ) {
      invalidCursor();
    }
    return [...envelope.p];
  } catch (error) {
    if (error instanceof InvalidOpaqueCursorError) throw error;
    invalidCursor();
  }
}
