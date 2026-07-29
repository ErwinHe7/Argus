import { NextResponse } from 'next/server';
import { z } from 'zod';
import { chat } from '@/lib/llm';

export const runtime = 'nodejs';
export const maxDuration = 30;

const Input = z.object({
  hint: z.string().min(2).max(500),
  category: z.string().max(40).optional(),
});

const SYSTEM = `You are a listing-writer AI for a NYC marketplace. Given a short hint and a category, produce a polished listing. Respond ONLY as compact JSON with this shape:
{"title": "...", "description": "...", "suggested_price_cents": 0}
Rules:
- Title: 5-10 words, concrete nouns first, no emoji.
- Description: 3-5 short lines, plain text, mention condition + pickup/logistics.
- suggested_price_cents: a realistic NYC 2026 price in cents (e.g. 12000 for $120). Use 0 if you cannot estimate.`;

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = Input.safeParse(json);
  if (!parsed.success) return NextResponse.json({ error: 'invalid input' }, { status: 400 });

  const user = `HINT: """${parsed.data.hint}"""\nCATEGORY: ${parsed.data.category ?? 'unknown'}\n\nWrite the listing.`;
  try {
    const raw = await chat(
      [
        { role: 'system', content: SYSTEM },
        { role: 'user', content: user },
      ],
      { temperature: 0.5, max_tokens: 400 }
    );
    const cleaned = raw.replace(/```json\s*/i, '').replace(/```$/i, '').trim();
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) return NextResponse.json({ error: 'parse failed', raw: cleaned }, { status: 502 });
    const obj = JSON.parse(match[0]);
    return NextResponse.json({
      title: String(obj.title ?? '').slice(0, 140),
      description: String(obj.description ?? '').slice(0, 4000),
      suggested_price_cents: Math.max(0, Math.round(Number(obj.suggested_price_cents) || 0)),
    });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
