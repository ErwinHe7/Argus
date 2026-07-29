import { NextRequest, NextResponse } from 'next/server';
import { runSerenityResearch } from '@/lib/research/serenity';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const ROUTE = '/api/research/serenity';

export async function POST(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;
  const key = rateLimitKey(req, ROUTE);
  const rate = checkRateLimit(key, 4, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: '请求过于频繁，请稍后再试。' }, { status: 429 });
  }

  if (!process.env.OPENAI_API_KEY) {
    return NextResponse.json({ error: 'LLM 未配置（缺少 OPENAI_API_KEY）。' }, { status: 503 });
  }

  const body = await req.json().catch(() => ({} as Record<string, unknown>));
  const topic = typeof (body as { topic?: unknown }).topic === 'string'
    ? (body as { topic: string }).topic
    : '';

  if (!topic.trim()) {
    return NextResponse.json({ error: '请输入研究主题。' }, { status: 400 });
  }

  try {
    const result = await runSerenityResearch(topic);
    return NextResponse.json(result, { headers: { 'Cache-Control': 'no-store' } });
  } catch (err) {
    console.error('[/api/research/serenity]', err);
    const msg = err instanceof Error ? err.message : '研究失败';
    return NextResponse.json({ error: `研究失败：${msg}` }, { status: 503 });
  }
}
