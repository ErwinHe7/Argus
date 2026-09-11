import type { JournalRecord } from './types';
export const STORAGE_KEY = 'leo.research-desk.records.v1';
export function parseRecords(value: string | null): JournalRecord[] {
  try {
    const records: unknown = JSON.parse(value ?? '[]');
    if (!Array.isArray(records)) return [];
    return records.filter((r): r is JournalRecord => r && typeof r === 'object' && ['algo', 'positions', 'earnings'].includes(r.kind) && ['open', 'closed'].includes(r.status) && ['id','symbol','date','session','thesis','source','reference','review'].every(k => typeof r[k] === 'string')).slice(0, 200);
  } catch { return []; }
}
export function safeReturn(value: string | null, origin: string): string {
  try {
    const url = new URL(value ?? '/app/?preview=1#/discover', origin);
    if (url.origin === origin && url.pathname === '/app/' && /^#\/(discover|you|gospel)(\/[^?]*)?$/.test(url.hash)) {
      const safe = new URL('/app/', origin);
      if (url.searchParams.get('preview') === '1') safe.searchParams.set('preview', '1');
      const version = url.searchParams.get('v');
      if (version && /^[a-zA-Z0-9._-]{1,80}$/.test(version)) safe.searchParams.set('v', version);
      safe.hash = url.hash;
      return safe.href;
    }
  } catch { /* Fall back to the same-origin app. */ }
  return new URL('/app/?preview=1#/discover', origin).href;
}
export function download(name: string, data: unknown) {
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], {type:'application/json'}));
  const link = document.createElement('a'); link.href = url; link.download = name; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
