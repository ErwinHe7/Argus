import 'server-only';

import { createHash } from 'node:crypto';
import { z } from 'zod';
import { requirePaidResearchAccess } from '@/lib/research-access';
import rawSnapshots from './artifacts/snapshots.json';
import publication from './artifacts/publication.json';
import { validateMarketMapSnapshot } from './validate';
import type { MarketMapHorizon, MarketMapSnapshot } from './types';

const publicationSchema = z.object({
  schema_version: z.literal('market-map-publication.v1'),
  generated_at: z.string().datetime({ offset: true }),
  expires_at: z.string().datetime({ offset: true }),
  rights_validation: z.array(z.object({
    status: z.literal('READY'), provider: z.string().min(1), product: z.string().min(1),
    source_ids: z.array(z.string().min(1)).min(1),
    expires_at: z.string().datetime({ offset: true }),
    receipt_sha256: z.string().regex(/^[a-f0-9]{64}$/),
  }).strict()).min(1),
  artifacts: z.array(z.object({
    key: z.string().regex(/^[A-Z][A-Z0-9.-]{0,15}:(?:5|10|20|60)d$/),
    sha256: z.string().regex(/^[a-f0-9]{64}$/), source_ids: z.array(z.string().min(1)).min(1),
  }).strict()).min(1),
}).strict();

async function memberCanView() {
  const access = await requirePaidResearchAccess();
  // RITUAL_FREE_PREVIEW never grants market-data rights to anonymous visitors.
  return access.allowed && access.user.authenticated;
}

function validatedPublishedSnapshots(): MarketMapSnapshot[] {
  const now = new Date();
  const parsed = publicationSchema.safeParse(publication);
  if (!parsed.success) return [];
  const manifest = parsed.data;
  if (Date.parse(manifest.expires_at) <= now.getTime() || Date.parse(manifest.generated_at) > now.getTime()) return [];
  const rights = manifest.rights_validation;
  if (rights.some((receipt) => Date.parse(receipt.expires_at) <= now.getTime())) return [];
  const coveredSources = new Set(rights.flatMap((receipt) => receipt.source_ids));
  const snapshots = rawSnapshots as Record<string, unknown>;
  return manifest.artifacts.flatMap((entry) => {
    if (!entry.source_ids.every((source) => coveredSources.has(source))) return [];
    const raw = snapshots[entry.key];
    if (!raw || createHash('sha256').update(JSON.stringify(raw)).digest('hex') !== entry.sha256) return [];
    const snapshot = validateMarketMapSnapshot(raw, { now });
    if (snapshot && entry.key !== `${snapshot.asset.symbol}:${snapshot.horizon}`) return [];
    if (!snapshot || !snapshot.provenance.sources.every((source) => rights.some((receipt) =>
      receipt.provider === source.provider.toLowerCase() && receipt.source_ids.includes(source.id)))) return [];
    return [snapshot];
  });
}

export async function listMarketMapSnapshots(): Promise<MarketMapSnapshot[]> {
  if (!await memberCanView()) return [];
  return validatedPublishedSnapshots().filter((snapshot) => snapshot.horizon === '20d');
}

export async function getMarketMapSnapshot(
  symbol: string,
  horizon: MarketMapHorizon = '20d',
): Promise<MarketMapSnapshot | null> {
  if (!/^[A-Z][A-Z0-9.-]{0,15}$/.test(symbol) || !await memberCanView()) return null;
  return validatedPublishedSnapshots().find((snapshot) =>
    snapshot.asset.symbol === symbol && snapshot.horizon === horizon,
  ) ?? null;
}

export async function getMarketMapReview(horizon: MarketMapHorizon = '20d'): Promise<MarketMapSnapshot | null> {
  const artifact = horizon === '5d' ? await import('./artifacts/review-5d.json')
    : horizon === '10d' ? await import('./artifacts/review-10d.json')
      : horizon === '60d' ? await import('./artifacts/review-60d.json')
        : await import('./artifacts/review.json');
  const review = artifact.default as { mode?: string; snapshot?: unknown };
  if (review.mode !== 'illustrative_review_only') return null;
  return validateMarketMapSnapshot(review.snapshot, { review: true, horizon });
}
