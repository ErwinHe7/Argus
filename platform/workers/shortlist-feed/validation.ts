import { publicationFuture, publicationSchema, type Publication } from '../../features/research-desk/shortlist/publication';

export const MAX_PUBLICATION_BYTES = 512 * 1024;

export class PublicationError extends Error {
  constructor(readonly code: string, readonly status: number) { super(code); }
}

/** Stable transport identity only; no ranking or financial calculation. */
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  const object = value as Record<string, unknown>;
  return `{${Object.keys(object).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(object[key])}`).join(',')}}`;
}

export function validatePublication(payload: string, now = Date.now()): Publication {
  if (new TextEncoder().encode(payload).byteLength > MAX_PUBLICATION_BYTES) throw new PublicationError('publication_too_large', 413);
  let raw: unknown;
  try { raw = JSON.parse(payload); }
  catch { throw new PublicationError('invalid_publication', 400); }
  const result = publicationSchema.safeParse(raw);
  if (!result.success) throw new PublicationError('invalid_publication', 400);
  if (publicationFuture(result.data, now)) throw new PublicationError('future_publication', 422);
  return result.data;
}

export async function readPublicationBody(request: Request): Promise<string> {
  const length = request.headers.get('content-length');
  if (length !== null && (!/^\d+$/.test(length) || Number(length) > MAX_PUBLICATION_BYTES)) throw new PublicationError('publication_too_large', 413);
  if (!request.body) throw new PublicationError('invalid_publication', 400);
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      bytes += chunk.value.byteLength;
      if (bytes > MAX_PUBLICATION_BYTES) {
        await reader.cancel();
        throw new PublicationError('publication_too_large', 413);
      }
      chunks.push(chunk.value);
    }
  } finally { reader.releaseLock(); }
  const payload = new Uint8Array(bytes);
  let offset = 0;
  for (const chunk of chunks) { payload.set(chunk, offset); offset += chunk.byteLength; }
  try { return new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(payload); }
  catch { throw new PublicationError('invalid_publication', 400); }
}

export function assertMonotonic(previous: Publication, next: Publication): void {
  const older = (a: string, b: string) => Date.parse(a) < Date.parse(b);
  if (older(next.publisher.heartbeatAt, previous.publisher.heartbeatAt)) throw new PublicationError('heartbeat_regressed', 409);
  if (Date.parse(next.publisher.heartbeatAt) === Date.parse(previous.publisher.heartbeatAt)) throw new PublicationError('heartbeat_conflict', 409);
  if (previous.shortlist && !next.shortlist) throw new PublicationError('published_artifact_required', 409);
  if (previous.shortlist && next.shortlist && (
    next.shortlist.asOf < previous.shortlist.asOf || older(next.shortlist.sourceRetrievedAt, previous.shortlist.sourceRetrievedAt)
  )) throw new PublicationError('source_regressed', 409);
  if (previous.shortlist && next.shortlist) {
    const observations = new Map<string, { sourceRetrievedAt: string; priceObservedAt: string }[]>();
    for (const row of [...previous.shortlist.stocks, ...previous.shortlist.funds]) {
      const prior = observations.get(row.symbol) ?? [];
      prior.push(row);
      observations.set(row.symbol, prior);
    }
    for (const row of [...next.shortlist.stocks, ...next.shortlist.funds]) {
      if (observations.get(row.symbol)?.some(prior => older(row.sourceRetrievedAt, prior.sourceRetrievedAt)
        || older(row.priceObservedAt, prior.priceObservedAt))) throw new PublicationError('source_regressed', 409);
    }
  }
  if (previous.publisher.publishedAt && next.publisher.publishedAt && older(next.publisher.publishedAt, previous.publisher.publishedAt)) {
    throw new PublicationError('publication_time_regressed', 409);
  }
}
