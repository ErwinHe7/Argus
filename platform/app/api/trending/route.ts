import { NextResponse } from 'next/server';
import { getTrendingPosts } from '@/lib/store';

export const runtime = 'nodejs';

export async function GET() {
  const posts = await getTrendingPosts(8);
  return NextResponse.json({ posts });
}
