export function versionFromEtag(etag: string): number {
  return Number(etag.slice(2, -1));
}

export function validateHistoryRange(from?: string, to?: string): boolean {
  if (from === undefined && to === undefined) return true;
  if (from === undefined || to === undefined) return false;
  const days = Math.floor((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
  return days >= 0 && days <= 366;
}
