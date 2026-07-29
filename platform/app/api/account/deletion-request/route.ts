import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user.authenticated) return NextResponse.json({ error: 'sign in required' }, { status: 401 });
  if (!isSupabaseConfigured()) return NextResponse.json({ error: 'account deletion requests are not configured' }, { status: 503 });

  const json = await req.json().catch(() => ({}));
  const notes = typeof json?.notes === 'string' ? json.notes.trim().slice(0, 1000) : null;

  const supabase = supabaseAdmin();
  const { data: existing, error: existingError } = await supabase
    .from('account_deletion_requests')
    .select('id, requested_at, status')
    .eq('user_id', user.id)
    .in('status', ['pending', 'processing'])
    .order('requested_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existingError) return NextResponse.json({ error: existingError.message }, { status: 500 });
  if (existing) return NextResponse.json({ ok: true, request: existing, duplicate: true });

  const { data, error } = await supabase
    .from('account_deletion_requests')
    .insert({ user_id: user.id, email: user.email ?? null, notes })
    .select('id, requested_at, status')
    .single();

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ ok: true, request: data });
}
