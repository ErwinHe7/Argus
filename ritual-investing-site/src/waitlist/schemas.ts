export const WAITLIST_NOTICE_VERSION = "waitlist-v1-2026-08-25";
export const MAX_WAITLIST_REQUEST_BYTES = 4_096;
export const MAX_TURNSTILE_TOKEN_BYTES = 2_048;

export type WaitlistSubmission = {
  normalizedEmail: string;
  noticeVersion: typeof WAITLIST_NOTICE_VERSION;
  turnstileToken: string;
};

export type WaitlistSchemaFailure = "schema" | "consent" | "notice";

export type WaitlistSchemaResult =
  | { ok: true; value: WaitlistSubmission }
  | { ok: false; failure: WaitlistSchemaFailure };

const EXPECTED_FIELDS = ["consent", "email", "noticeVersion", "turnstileToken"] as const;
const EMAIL_SHAPE = /^[^\s@]+@[^\s@]+$/;

function isExactSubmissionObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;
  const keys = Object.keys(value).sort();
  return keys.length === EXPECTED_FIELDS.length &&
    keys.every((key, index) => key === EXPECTED_FIELDS[index]);
}

function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (
    normalized.length < 3 ||
    normalized.length > 254 ||
    normalized.includes("\0") ||
    !EMAIL_SHAPE.test(normalized)
  ) return null;
  return normalized;
}

export function parseWaitlistSubmission(serialized: string): WaitlistSchemaResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(serialized);
  } catch {
    return { ok: false, failure: "schema" };
  }
  if (!isExactSubmissionObject(parsed)) return { ok: false, failure: "schema" };

  const email = normalizeEmail(parsed.email);
  if (
    email === null ||
    typeof parsed.turnstileToken !== "string" ||
    parsed.turnstileToken.length === 0 ||
    new TextEncoder().encode(parsed.turnstileToken).byteLength > MAX_TURNSTILE_TOKEN_BYTES ||
    typeof parsed.noticeVersion !== "string" ||
    typeof parsed.consent !== "boolean"
  ) return { ok: false, failure: "schema" };

  if (parsed.consent !== true) return { ok: false, failure: "consent" };
  if (parsed.noticeVersion !== WAITLIST_NOTICE_VERSION) return { ok: false, failure: "notice" };

  return {
    ok: true,
    value: {
      normalizedEmail: email,
      noticeVersion: WAITLIST_NOTICE_VERSION,
      turnstileToken: parsed.turnstileToken,
    },
  };
}
