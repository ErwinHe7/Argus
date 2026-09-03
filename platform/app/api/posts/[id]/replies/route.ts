import { NextResponse } from 'next/server';
import { listReplies } from '@/lib/store';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(_req: Request, { params }: { params: { id: string } }) {
  const replies = await listReplies(params.id).catch(() => []);
  return NextResponse.json({ replies });
}
