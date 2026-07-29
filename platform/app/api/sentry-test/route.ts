import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export function GET() {
  throw new Error('Sentry test error — delete /app/api/sentry-test after verifying');
  return NextResponse.json({ ok: true });
}
