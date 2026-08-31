export const GUEST_COOKIE = 'axio7_guest_id';
export const AXIO_HANDLE_PREFIX = 'AXIO@';

// Generates handles like AXIO@4F2A9C — 6 uppercase hex chars
// Looks like a memory address / hash, signals technical identity without exposing user count
export function createAxioHandle(seed?: string): string {
  const raw =
    seed ||
    globalThis.crypto?.randomUUID?.() ||
    Math.random().toString(16).slice(2) + Date.now().toString(16);
  const hex = raw.replace(/[^a-fA-F0-9]/g, '').padEnd(6, '0').slice(0, 6).toUpperCase();
  return `${AXIO_HANDLE_PREFIX}${hex}`;
}

export function normalizeAxioHandle(value: string | null | undefined): string {
  if (!value) return createAxioHandle('anon');
  // Already new format AXIO@XXXXXX
  if (/^AXIO@[0-9A-F]{6}$/i.test(value)) {
    return `AXIO@${value.slice(5).toUpperCase()}`;
  }
  // Legacy format Axio0xXXXXXX — migrate to new format, preserve the hex
  if (/^axio0x/i.test(value)) {
    const hex = value.replace(/^axio0x/i, '').replace(/[^a-fA-F0-9]/g, '').slice(0, 6).toUpperCase();
    return `AXIO@${hex.padEnd(6, '0')}`;
  }
  if (/^guest-/i.test(value)) {
    return createAxioHandle(value);
  }
  return value;
}
