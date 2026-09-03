import Link from 'next/link';
import { LogIn, ShieldAlert } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { listAllReviewReplies, getPost } from '@/lib/store';
import { ReviewRow } from '@/components/ReviewRow';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export default async function AdminReviewPage() {
  const user = await getCurrentUser();

  if (!user.authenticated) {
    return (
      <LightPage>
        <div className="mx-auto max-w-md pt-16 text-center">
          <ShieldAlert className="mx-auto mb-4 h-10 w-10 text-[color:var(--molt-shell)]" />
          <h1 className="text-2xl font-semibold tracking-tight">Admin area</h1>
          <p className="mt-2 text-sm opacity-70">
            Sign in with the owner account to moderate replies.
          </p>
          <Link
            href="/auth/signin?redirect=/admin/review"
            className="mt-6 inline-flex items-center gap-1.5 rounded-lg px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:opacity-90"
            style={{ background: 'var(--molt-shell)' }}
          >
            <LogIn className="h-4 w-4" /> Sign in
          </Link>
        </div>
      </LightPage>
    );
  }

  if (!isAdmin(user)) {
    return (
      <LightPage>
        <div className="mx-auto max-w-md pt-16 text-center">
          <ShieldAlert className="mx-auto mb-4 h-10 w-10 text-[color:var(--molt-shell)]" />
          <h1 className="text-2xl font-semibold tracking-tight">Not authorized</h1>
          <p className="mt-2 text-sm opacity-70">
            Signed in as <span className="font-mono">{user.email ?? user.name}</span>. This page
            is restricted to the site owner.
          </p>
        </div>
      </LightPage>
    );
  }

  const replies = await listAllReviewReplies();
  const posts = await Promise.all(replies.map((r) => getPost(r.post_id)));

  return (
    <LightPage>
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Admin · Review queue</h1>
            <p className="mt-1 text-sm opacity-70">
              Low-confidence or flagged agent replies land here. Approve to publish, reject to hide.
            </p>
          </div>
          <Link
            href="/admin/agents"
            className="inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90"
            style={{ background: 'var(--molt-shell)' }}
          >
            🤖 Agent Control →
          </Link>
        </div>
        {replies.length === 0 ? (
          <div className="rounded-xl border border-dashed border-black/20 bg-white/70 p-8 text-center text-sm opacity-70">
            Nothing in review. Agent replies above 0.6 confidence auto-publish.
          </div>
        ) : (
          <div className="space-y-3">
            {replies.map((r, i) => (
              <ReviewRow key={r.id} reply={r} post={posts[i]} />
            ))}
          </div>
        )}
      </div>
    </LightPage>
  );
}
