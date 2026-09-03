import { NextResponse } from 'next/server';
import { supabaseAdmin, isSupabaseConfigured } from '@/lib/supabase';
import { getSourceStatuses } from '@/lib/market-intelligence/sources';
import { getBrokerAdapter } from '@/lib/market-intelligence/broker';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  const sources = getSourceStatuses();
  const broker = getBrokerAdapter();

  const env = {
    node: process.version,
    region: process.env.VERCEL_REGION || process.env.AWS_REGION || 'unknown',
    deployment: process.env.VERCEL_GIT_COMMIT_SHA || process.env.GIT_COMMIT || 'local',
  };

  const providers = sources.map((source) => ({
    id: source.id,
    name: source.name,
    kind: source.kind,
    access: source.access,
    productionReady: source.productionReady,
    enabled: source.enabled,
  }));

  const productionReadyCount = providers.filter((p) => p.productionReady).length;

  const supabase = await checkSupabase();

  return NextResponse.json(
    {
      status: supabase.ok ? 'ok' : 'degraded',
      ts: new Date().toISOString(),
      env,
      supabase,
      broker: { name: broker.name, mode: broker.mode },
      providers,
      coverage: {
        productionReady: productionReadyCount,
        total: providers.length,
        pct: Math.round((productionReadyCount / Math.max(1, providers.length)) * 100),
      },
    },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}

async function checkSupabase() {
  if (!isSupabaseConfigured()) {
    return { ok: false, reason: 'not_configured' as const };
  }
  try {
    const { error } = await supabaseAdmin().from('posts').select('count').single();
    if (error) return { ok: false, reason: 'db_error' as const, code: error.code, message: error.message };
    return { ok: true as const };
  } catch (err) {
    return { ok: false, reason: 'exception' as const, message: err instanceof Error ? err.message : 'unknown' };
  }
}
