import type { Metadata } from 'next';
import { LightPage } from '@/components/LightPage';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { getPost, listReplies } from '@/lib/store';
import { PostCard } from '@/components/PostCard';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const post = await getPost(params.id).catch(() => null);
  if (!post) return { title: 'Post not found — AXIO7' };

  const excerpt = post.content.slice(0, 160);

  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://axio7.com';

  const ogImage = post.images?.[0] ?? `${siteUrl}/og-default.png`;

  return {
    title: `${post.author_name} on AXIO7`,
    description: excerpt,
    openGraph: {
      title: `${post.author_name} on AXIO7`,
      description: excerpt,
      url: `${siteUrl}/post/${post.id}`,
      siteName: 'AXIO7',
      images: [{ url: ogImage, width: 1200, height: 630 }],
      type: 'article',
    },
    twitter: {
      card: 'summary_large_image',
      title: `${post.author_name} on AXIO7`,
      description: excerpt,
      images: [ogImage],
    },
  };
}

export default async function PostDetail({ params }: { params: { id: string } }) {
  const [post, user] = await Promise.all([getPost(params.id), getCurrentUser()]);
  if (!post) return notFound();
  const replies = await listReplies(post.id);

  return (
    <LightPage><div className="space-y-4">
      <Link href="/" className="inline-flex items-center gap-1 text-sm text-ink-muted hover:text-ink">
        <ArrowLeft className="h-4 w-4" /> Back to Feed
      </Link>
      <PostCard
        post={post}
        replies={replies}
        canDelete={isAdmin(user) || post.author_id === user.id}
        canPin={isAdmin(user)}
      />
    </div></LightPage>
  );
}
