import { NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type SupabaseAuthSettings = {
  external?: {
    apple?: unknown;
    email?: unknown;
    google?: unknown;
  };
};

const unavailableProviders = {
  apple: false,
  email: false,
  google: false,
} as const;

export async function GET() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim();
  if (!supabaseUrl || !anonKey) {
    return NextResponse.json(unavailableProviders, {
      status: 503,
      headers: { 'cache-control': 'no-store' },
    });
  }

  try {
    const response = await fetch(
      `${supabaseUrl.replace(/\/+$/, '')}/auth/v1/settings`,
      {
        cache: 'no-store',
        headers: { apikey: anonKey },
      }
    );
    if (!response.ok) {
      throw new Error(`Supabase auth settings returned ${response.status}.`);
    }

    const settings = (await response.json()) as SupabaseAuthSettings;
    return NextResponse.json(
      {
        apple: settings.external?.apple === true,
        email: settings.external?.email === true,
        google: settings.external?.google === true,
      },
      { headers: { 'cache-control': 'no-store' } }
    );
  } catch (error) {
    console.error(
      '[auth] Unable to read provider availability',
      error instanceof Error ? error.message : 'unknown_error'
    );
    return NextResponse.json(unavailableProviders, {
      status: 502,
      headers: { 'cache-control': 'no-store' },
    });
  }
}
