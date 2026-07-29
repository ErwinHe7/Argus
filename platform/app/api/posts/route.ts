import { NextResponse } from 'next/server';
import { z } from 'zod';
import { createPost, listPosts, getDisplayName } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const posts = await listPosts();
    return NextResponse.json({ posts });
  } catch (err: any) {
    console.error('[GET /api/posts]', err?.message);
    return NextResponse.json({ posts: [], error: err?.message ?? 'db error' }, { status: 500 });
  }
}

const PostInput = z.object({
  author_name: z.string().max(80).optional(),
  content: z.string().min(1).max(2000),
  images: z.array(z.string().url()).max(4).optional(),
});

async function checkPostRateLimit(authorId: string, content: string) {
  const recentPosts = await listPosts(100);
  const now = Date.now();
  const mine = recentPosts.filter((post) => post.author_id === authorId);
  const myTimes = mine
    .map((post) => new Date(post.created_at).getTime())
    .filter((time) => Number.isFinite(time));

  // 1. Hard cooldown: 30s between posts
  const lastPostAt = myTimes.length > 0 ? Math.max(...myTimes) : 0;
  if (lastPostAt && now - lastPostAt < 30_000) {
    return 'Please wait 30 seconds before posting again.';
  }

  // 2. Burst limit: max 3 posts per 10 minutes
  const tenMinutesAgo = now - 10 * 60_000;
  if (myTimes.filter((t) => t >= tenMinutesAgo).length >= 3) {
    return 'Too many posts. Please wait a few minutes.';
  }

  // 3. Hourly cap: max 10 posts per hour
  const oneHourAgo = now - 60 * 60_000;
  if (myTimes.filter((t) => t >= oneHourAgo).length >= 10) {
    return 'Hourly post limit reached. Try again later.';
  }

  // 4. Duplicate content check: block identical or near-identical content
  const trimmed = content.trim().toLowerCase();
  const duplicate = mine.find((post) => {
    const existing = post.content.trim().toLowerCase();
    // Exact match
    if (existing === trimmed) return true;
    // Very short content (≤10 chars) posted more than once
    if (trimmed.length <= 10 && existing === trimmed) return true;
    return false;
  });
  if (duplicate) {
    return 'You have already sent similar content.';
  }

  // 5. Single-character / purely whitespace spam detection
  if (trimmed.length <= 2) {
    const shortPosts = mine.filter((p) => p.content.trim().length <= 2);
    if (shortPosts.length >= 2) {
      return 'You have already sent similar content.';
    }
  }

  return null;
}

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = PostInput.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: 'invalid input' }, { status: 400 });
  }
  try {
    const user = await getCurrentUser();

    // Must be signed in to post
    if (!user.authenticated) {
      return NextResponse.json(
        { error: 'Sign in required. Create a free account to post.' },
        { status: 401 }
      );
    }

    const rateLimitError = await checkPostRateLimit(user.id, parsed.data.content);
    if (rateLimitError) {
      return NextResponse.json({ error: rateLimitError }, { status: 429 });
    }

    // Prefer custom display name if set, then auth name
    const customName = await getDisplayName(user.id);
    const post = await createPost({
      author_id: user.id,
      author_name: customName || user.name || user.email?.split('@')[0] || 'User',
      author_avatar: user.avatar,
      content: parsed.data.content,
      images: parsed.data.images ?? [],
    });

    // Fan-out runs in /api/fanout (maxDuration=60) — triggered by the client after
    // this response returns so Vercel hobby plan's 10s limit isn't hit here.
    return NextResponse.json({ post });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
