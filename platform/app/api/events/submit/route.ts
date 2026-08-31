import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';
import { getCurrentUser } from '@/lib/auth';
import { inferCategory } from '@/lib/events/normalize';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const SubmitSchema = z.object({
  title: z.string().min(2).max(200),
  url: z.string().url().optional().or(z.literal('')),
  start_time: z.string().optional(),
  end_time: z.string().optional(),
  location: z.string().max(200).optional(),
  description: z.string().max(2000).optional(),
  poster_url: z.string().url().optional().or(z.literal('')),
  tags: z.array(z.string().max(40)).max(10).optional(),
  is_free: z.boolean().optional(),
  price_text: z.string().max(80).optional(),
});

async function checkRateLimit(authorId: string): Promise<boolean> {
  if (!isSupabaseConfigured()) return true;
  const tenMinAgo = new Date(Date.now() - 10 * 60_000).toISOString();
  const { count } = await supabaseAdmin()
    .from('events')
    .select('*', { count: 'exact', head: true })
    .eq('submitted_by_author_id', authorId)
    .eq('status', 'pending')
    .gte('created_at', tenMinAgo);
  return (count ?? 0) < 3;
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => null);
  const parsed = SubmitSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid input.', detail: parsed.error.flatten() }, { status: 400 });
  }

  const d = parsed.data;
  const user = await getCurrentUser();

  const allowed = await checkRateLimit(user.id);
  if (!allowed) {
    return NextResponse.json({ error: 'Too many submissions. Wait a few minutes.' }, { status: 429 });
  }

  // Auto-scrape og: tags if URL provided and title/description are sparse
  let scraped: { title?: string; description?: string; poster_url?: string } = {};
  if (d.url) {
    try {
      const r = await fetch(d.url, {
        headers: { 'User-Agent': 'AXIO7-Events-Bot/1.0' },
        signal: AbortSignal.timeout(5_000),
      });
      const html = await r.text();
      const ogTitle = html.match(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)/i)?.[1];
      const ogDesc = html.match(/<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)/i)?.[1];
      const ogImage = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)/i)?.[1];
      if (ogTitle) scraped.title = ogTitle;
      if (ogDesc) scraped.description = ogDesc;
      if (ogImage) scraped.poster_url = ogImage;
    } catch {
      // silently skip — never block form
    }
  }

  const title = d.title || scraped.title || '';
  if (!title) return NextResponse.json({ error: 'Title is required.' }, { status: 400 });

  const description = d.description || scraped.description || null;
  const poster_url = (d.poster_url || scraped.poster_url) || null;
  const tags = d.tags ?? [];
  const category = inferCategory(title, description, tags);

  if (!isSupabaseConfigured()) {
    return NextResponse.json({ ok: true, note: 'Demo mode — event not persisted.', event: { title, status: 'pending' } });
  }

  // Get User Submission source
  const { data: source } = await supabaseAdmin()
    .from('event_sources')
    .select('id')
    .eq('name', 'User Submission')
    .maybeSingle();

  const { data: event, error } = await supabaseAdmin()
    .from('events')
    .insert({
      source_id: source?.id ?? null,
      external_id: `user-${user.id}-${Date.now()}`,
      title,
      description,
      start_time: d.start_time || null,
      end_time: d.end_time || null,
      location: d.location || null,
      borough: null,
      url: d.url || null,
      poster_url,
      tags,
      category,
      price_text: d.price_text || null,
      is_free: d.is_free ?? null,
      submitted_by_author_id: user.id,
      status: 'pending',
    })
    .select('id, title, status')
    .single();

  if (error) {
    return NextResponse.json({ error: 'Failed to submit event.' }, { status: 500 });
  }

  return NextResponse.json({ ok: true, event });
}
