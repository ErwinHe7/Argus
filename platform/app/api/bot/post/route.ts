import { NextResponse } from 'next/server';
import { createPost } from '@/lib/store';
import { pickBotPost } from '@/lib/bot-posts';

export const runtime = 'nodejs';

export async function POST(req: Request) {
  // Simple secret check to prevent abuse
  const secret = req.headers.get('x-cron-secret');
  if (process.env.CRON_SECRET && secret !== process.env.CRON_SECRET) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  const botPost = pickBotPost();
  const post = await createPost({
    author_id: `bot-${Date.now()}`,
    author_name: botPost.author_name,
    author_avatar: botPost.author_avatar,
    content: botPost.content,
    images: botPost.images ?? [],
  });

  // Trigger agent fanout
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com';
  fetch(`${siteUrl}/api/fanout`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ post_id: post.id }),
  }).catch(() => {});

  return NextResponse.json({ ok: true, post_id: post.id });
}

export async function GET(req: Request) {
  // Vercel cron calls GET
  return POST(req);
}
