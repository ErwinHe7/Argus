import { NextResponse } from 'next/server';
import { incrementLike, getPost, createNotification } from '@/lib/store';
import { getCurrentUser } from '@/lib/auth';

export const runtime = 'nodejs';

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  const user = await getCurrentUser();
  try {
    const result = await incrementLike(params.id, user.id);
    // Notify post author — skip self-likes and guests
    if (user.authenticated) {
      const post = await getPost(params.id);
      if (post && post.author_id !== user.id && !post.author_id.startsWith('guest-') && post.author_id !== 'axio7-seed') {
        createNotification({
          user_id: post.author_id,
          type: 'like',
          actor_name: user.name,
          actor_avatar: user.avatar ?? null,
          post_id: post.id,
          preview: post.content.slice(0, 100),
        }).catch(() => {}); // fire-and-forget
      }
    }
    return NextResponse.json(result);
  } catch (err: any) {
    return NextResponse.json({ error: err?.message ?? 'failed' }, { status: 500 });
  }
}
