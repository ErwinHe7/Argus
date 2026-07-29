import { NextResponse } from 'next/server';
import { supabaseServer } from '@/lib/supabase';
import { isSupabaseConfigured } from '@/lib/supabase';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export async function GET() {
  if (!isSupabaseConfigured()) return NextResponse.json({ configured: false });
  try {
    const { data: { user }, error } = await supabaseServer().auth.getUser();
    return NextResponse.json({ configured: true, user: user ? { id: user.id, email: user.email, name: user.user_metadata?.full_name } : null, error: error?.message });
  } catch (e: any) {
    return NextResponse.json({ configured: true, error: e.message });
  }
}
