import { randomUUID } from 'crypto';
import { isSupabaseConfigured, supabaseAdmin } from './supabase';
import { normalizeAxioHandle } from './guest-identity';
import type { Bid, Listing, Post, Reply, AgentReplyMeta, Reaction, Transaction, Message, AgentProfileRow, Notification, NotificationType } from './types';

// Dual-mode store.
// - If Supabase env vars are set → all reads/writes hit Supabase (persists on Vercel serverless).
// - Else → in-memory fallback so local dev runs without any DB setup.
// API is async either way.

type DB = {
  posts: Post[];
  replies: Reply[];
  reply_meta: Record<string, AgentReplyMeta>;
  listings: Listing[];
  bids: Bid[];
  reactions: Reaction[];
  post_likes: { post_id: string; user_id: string }[];
  transactions: Transaction[];
  messages: Message[];
  review_queue: { id: string; reply_id: string; reason: string; status: 'open' | 'approved' | 'rejected'; created_at: string }[];
};

const g = globalThis as unknown as { __axio7_db?: DB };

function seed(): DB {
  const seedUser = {
    id: 'seed-user-1',
    name: 'Leo Member',
    avatar: 'https://api.dicebear.com/9.x/thumbs/svg?seed=Leo-Member',
  };

  const posts: Post[] = [
    {
      id: randomUUID(),
      author_id: seedUser.id,
      author_name: seedUser.name,
      author_avatar: seedUser.avatar,
      content:
        'Watching NVDA, TSLA, and COIN into earnings. Which public catalysts are actually moving the tape today?',
      images: [],
      created_at: new Date(Date.now() - 3600_000 * 4).toISOString(),
      reply_count: 0,
      like_count: 12,
    },
    {
      id: randomUUID(),
      author_id: 'seed-user-2',
      author_name: 'Mei',
      author_avatar: 'https://api.dicebear.com/9.x/thumbs/svg?seed=Mei',
      content:
        "Selling my IKEA Malm desk + chair — graduating and moving home. What's a fair price when the thrift market is saturated with May move-outs?",
      images: [],
      created_at: new Date(Date.now() - 3600_000 * 2).toISOString(),
      reply_count: 0,
      like_count: 3,
    },
    {
      id: randomUUID(),
      author_id: 'seed-user-3',
      author_name: 'Jordan',
      author_avatar: 'https://api.dicebear.com/9.x/thumbs/svg?seed=Jordan',
      content: 'Feeling wrecked from thesis defense. Didn\'t sleep. Just need to vent for a second.',
      images: [],
      created_at: new Date(Date.now() - 60_000 * 40).toISOString(),
      reply_count: 0,
      like_count: 8,
    },
  ];

  const listings: Listing[] = [
    {
      id: randomUUID(),
      seller_id: 'seed-user-2',
      seller_name: 'Mei',
      seller_email: 'mei@example.com',
      seller_contact: 'Pickup around Columbia campus',
      category: 'furniture',
      title: 'IKEA Malm desk + chair (barely used)',
      description: 'Selling my desk + chair as I move out. Pickup in Morningside Heights. Perfect for a dorm or small apartment.',
      asking_price_cents: 12000,
      currency: 'USD',
      location: 'Morningside Heights, NYC',
      images: [],
      status: 'open',
      created_at: new Date(Date.now() - 3600_000 * 6).toISOString(),
      bid_count: 2,
      top_bid_cents: 9000,
    },
    {
      id: randomUUID(),
      seller_id: 'seed-user-4',
      seller_name: 'Sam',
      seller_email: 'sam@example.com',
      seller_contact: 'Text after email intro',
      category: 'books',
      title: 'Market Wizards + Security Analysis bundle',
      description: 'Classic investing and trading books. Good condition, margin notes in pencil.',
      asking_price_cents: 4500,
      currency: 'USD',
      location: 'New York, NY',
      images: [],
      status: 'open',
      created_at: new Date(Date.now() - 3600_000 * 12).toISOString(),
      bid_count: 0,
      top_bid_cents: null,
    },
    {
      id: randomUUID(),
      seller_id: 'seed-user-5',
      seller_name: 'Priya',
      seller_email: 'priya@example.com',
      seller_contact: 'Can meet near Midtown',
      category: 'electronics',
      title: 'iPad Pro 11" (2023) + Apple Pencil',
      description: 'Minor screen wear from use in school. Charger + case included.',
      asking_price_cents: 60000,
      currency: 'USD',
      location: 'Midtown, NYC',
      images: [],
      status: 'open',
      created_at: new Date(Date.now() - 3600_000 * 22).toISOString(),
      bid_count: 1,
      top_bid_cents: 55000,
    },
  ];

  return {
    posts,
    replies: [],
    reply_meta: {},
    listings,
    bids: [],
    reactions: [],
    post_likes: [],
    transactions: [],
    messages: [],
    review_queue: [],
  };
}

function mem(): DB {
  if (!g.__axio7_db) g.__axio7_db = seed();
  return g.__axio7_db;
}

function usingDB(): boolean {
  return isSupabaseConfigured();
}

// ----- Mappers (Supabase row → app type) -----

function publicAuthorName(name: string | null | undefined, authorId: string | null | undefined) {
  const trimmed = name?.trim();
  if (trimmed && !['guest', 'anonymous'].includes(trimmed.toLowerCase())) return trimmed;
  return normalizeAxioHandle(authorId ?? trimmed ?? '');
}

function mapPost(row: any): Post {
  const authorId = row.author_id ?? '';
  return {
    id: row.id,
    author_id: authorId,
    author_name: publicAuthorName(row.author_name, authorId),
    author_avatar: row.author_avatar ?? null,
    content: row.content,
    images: Array.isArray(row.images) ? row.images : [],
    created_at: row.created_at,
    reply_count: row.reply_count ?? 0,
    like_count: row.like_count ?? 0,
    pinned: row.pinned ?? false,
    author_kind: row.author_kind ?? 'human',
    agent_persona: row.agent_persona ?? null,
    is_autonomous: row.is_autonomous ?? false,
    autonomous_source: row.autonomous_source ?? null,
  };
}
function mapReply(row: any): Reply {
  return {
    id: row.id,
    post_id: row.post_id,
    author_kind: row.author_kind,
    author_id: row.author_id ?? '',
    author_name: row.author_name ?? 'Agent',
    author_avatar: row.author_avatar ?? null,
    agent_persona: row.agent_persona ?? null,
    content: row.content,
    created_at: row.created_at,
    confidence_score: row.confidence_score ?? null,
    visibility: row.visibility ?? 'public',
    up_count: row.up_count ?? 0,
    down_count: row.down_count ?? 0,
    is_autonomous: row.is_autonomous ?? false,
  };
}
function mapListing(row: any): Listing {
  return {
    id: row.id,
    seller_id: row.seller_id ?? '',
    seller_name: row.seller_name ?? 'Anonymous',
    seller_email: row.seller_email ?? null,
    seller_contact: row.seller_contact ?? null,
    category: row.category,
    title: row.title,
    description: row.description,
    asking_price_cents: row.asking_price_cents,
    currency: row.currency ?? 'USD',
    location: row.location ?? null,
    images: Array.isArray(row.images) ? row.images : [],
    status: row.status,
    created_at: row.created_at,
    bid_count: row.bid_count ?? 0,
    top_bid_cents: row.top_bid_cents ?? null,
  };
}

function isMissingDbColumn(error: any, columnName: string) {
  const message = String(error?.message ?? error?.details ?? '');
  return error?.code === 'PGRST204' && message.includes(`'${columnName}'`);
}
function mapBid(row: any): Bid {
  return {
    id: row.id,
    listing_id: row.listing_id,
    bidder_id: row.bidder_id ?? '',
    bidder_name: row.bidder_name ?? 'Anonymous',
    bidder_email: row.bidder_email ?? null,
    bidder_contact: row.bidder_contact ?? null,
    amount_cents: row.amount_cents,
    message: row.message ?? null,
    status: row.status,
    created_at: row.created_at,
  };
}

// ===== Posts =====

export async function listPosts(limit = 50): Promise<Post[]> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('posts')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data ?? []).map(mapPost);
  }
  return [...mem().posts].sort((a, b) => b.created_at.localeCompare(a.created_at)).slice(0, limit);
}

export async function getTrendingPosts(limit = 8): Promise<Post[]> {
  if (usingDB()) {
    // Pinned posts first, then score = like_count*3 + reply_count*2, decay by age
    const { data, error } = await supabaseAdmin()
      .from('posts')
      .select('*')
      .order('pinned', { ascending: false })
      .order('like_count', { ascending: false })
      .limit(limit * 3); // fetch more, score in JS
    if (error || !data) return [];
    const now = Date.now();
    return data
      .map((row: any) => {
        const p = mapPost(row);
        const ageHours = (now - new Date(p.created_at).getTime()) / 3_600_000;
        const score = (p.like_count * 3 + p.reply_count * 2) / Math.max(1, Math.pow(ageHours + 2, 0.8));
        return { ...p, _score: score };
      })
      .sort((a: any, b: any) => {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return b._score - a._score;
      })
      .slice(0, limit);
  }
  const posts = mem().posts;
  return [...posts].sort((a, b) => (b.like_count * 3 + b.reply_count * 2) - (a.like_count * 3 + a.reply_count * 2)).slice(0, limit);
}

export async function getPost(id: string): Promise<Post | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin().from('posts').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data ? mapPost(data) : null;
  }
  return mem().posts.find((p) => p.id === id) ?? null;
}

export async function createPost(input: {
  author_id?: string;
  author_name: string;
  author_avatar?: string | null;
  content: string;
  images?: string[];
  // Autonomous agent fields
  author_kind?: 'human' | 'agent';
  agent_persona?: string | null;
  is_autonomous?: boolean;
  autonomous_source?: string | null;
}): Promise<Post> {
  const authorId = input.author_id ?? normalizeAxioHandle(`guest-${randomUUID()}`);
  const name = publicAuthorName(input.author_name, authorId);
  const avatar =
    input.author_avatar ??
    `https://api.dicebear.com/9.x/thumbs/svg?seed=${encodeURIComponent(name)}`;
  const images = input.images ?? [];
  if (usingDB()) {
    // Try with autonomous fields first (requires migration 008).
    // If the columns don't exist yet, fall back to base fields only.
    const basePayload = {
      author_id: authorId,
      author_name: name,
      author_avatar: avatar,
      content: input.content,
      images,
    };
    const fullPayload = {
      ...basePayload,
      author_kind: input.author_kind ?? 'human',
      agent_persona: input.agent_persona ?? null,
      is_autonomous: input.is_autonomous ?? false,
      autonomous_source: input.autonomous_source ?? null,
    };

    let data: any = null;
    let error: any = null;

    ({ data, error } = await supabaseAdmin()
      .from('posts')
      .insert(fullPayload)
      .select('*')
      .single());

    // If error mentions missing column (migration 008 not yet run), retry with base payload
    if (error) {
      const msg: string = error?.message ?? '';
      const isMissingCol = msg.includes('column') && (
        msg.includes('agent_persona') ||
        msg.includes('is_autonomous') ||
        msg.includes('autonomous_source') ||
        msg.includes('author_kind') ||
        msg.includes('schema cache')
      );
      if (isMissingCol) {
        ({ data, error } = await supabaseAdmin()
          .from('posts')
          .insert(basePayload)
          .select('*')
          .single());
      }
    }

    if (error) throw error;
    return mapPost(data);
  }
  const p: Post = {
    id: randomUUID(),
    author_id: authorId,
    author_name: name,
    author_avatar: avatar,
    content: input.content,
    images,
    created_at: new Date().toISOString(),
    reply_count: 0,
    like_count: 0,
    author_kind: input.author_kind ?? 'human',
    agent_persona: input.agent_persona ?? null,
    is_autonomous: input.is_autonomous ?? false,
    autonomous_source: (input.autonomous_source as any) ?? null,
  };
  mem().posts.push(p);
  return p;
}

export async function deletePost(postId: string, userId: string, admin: boolean): Promise<boolean> {
  if (usingDB()) {
    const { data } = await supabaseAdmin().from('posts').select('author_id').eq('id', postId).single();
    if (!data) return false;
    if (!admin && data.author_id !== userId) return false;
    const { error } = await supabaseAdmin().from('posts').delete().eq('id', postId);
    return !error;
  }
  const db = mem();
  const idx = db.posts.findIndex((p) => p.id === postId);
  if (idx === -1) return false;
  if (!admin && db.posts[idx].author_id !== userId) return false;
  db.posts.splice(idx, 1);
  return true;
}

export async function pinPost(postId: string): Promise<boolean> {
  if (!usingDB()) return false;
  const { error } = await supabaseAdmin().from('posts').update({ pinned: true }).eq('id', postId);
  return !error;
}

export async function unpinPost(postId: string): Promise<boolean> {
  if (!usingDB()) return false;
  const { error } = await supabaseAdmin().from('posts').update({ pinned: false }).eq('id', postId);
  return !error;
}

export async function incrementLike(postId: string, userId: string): Promise<{ post: Post | null; liked: boolean }> {
  if (usingDB()) {
    const { data: existing } = await supabaseAdmin()
      .from('post_likes')
      .select('post_id')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .maybeSingle();
    if (existing) {
      await supabaseAdmin().from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
      await supabaseAdmin().rpc('decrement_post_like', { p_id: postId }).throwOnError();
    } else {
      await supabaseAdmin().from('post_likes').insert({ post_id: postId, user_id: userId });
      await supabaseAdmin().rpc('increment_post_like', { p_id: postId }).throwOnError();
    }
    const post = await getPost(postId);
    return { post, liked: !existing };
  }
  const likes = mem().post_likes;
  const idx = likes.findIndex((l) => l.post_id === postId && l.user_id === userId);
  const p = mem().posts.find((x) => x.id === postId);
  if (!p) return { post: null, liked: false };
  if (idx >= 0) {
    likes.splice(idx, 1);
    p.like_count = Math.max(0, p.like_count - 1);
    return { post: p, liked: false };
  }
  likes.push({ post_id: postId, user_id: userId });
  p.like_count += 1;
  return { post: p, liked: true };
}

// ===== Replies =====

export async function listReplies(postId: string, opts?: { includeReview?: boolean }): Promise<Reply[]> {
  if (usingDB()) {
    let q = supabaseAdmin().from('replies').select('*').eq('post_id', postId).order('created_at', { ascending: true });
    if (!opts?.includeReview) q = q.eq('visibility', 'public');
    const { data, error } = await q;
    if (error) throw error;
    return (data ?? []).map(mapReply);
  }
  return mem()
    .replies.filter((r) => r.post_id === postId && (opts?.includeReview || r.visibility !== 'review'))
    .sort((a, b) => a.created_at.localeCompare(b.created_at));
}

export async function listAllReviewReplies(): Promise<Reply[]> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('replies')
      .select('*')
      .eq('visibility', 'review')
      .order('created_at', { ascending: false })
      .limit(100);
    if (error) throw error;
    return (data ?? []).map(mapReply);
  }
  return mem()
    .replies.filter((r) => r.visibility === 'review')
    .sort((a, b) => b.created_at.localeCompare(a.created_at));
}

export async function getReply(id: string): Promise<Reply | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin().from('replies').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data ? mapReply(data) : null;
  }
  return mem().replies.find((r) => r.id === id) ?? null;
}

export async function createReply(input: {
  post_id: string;
  author_kind: 'human' | 'agent';
  author_id?: string | null;
  author_name: string;
  author_avatar?: string | null;
  agent_persona?: string | null;
  content: string;
  confidence_score?: number | null;
  visibility?: 'public' | 'review' | 'hidden';
  is_autonomous?: boolean;
  // Discussion engine fields (added in migration 010)
  reply_type?: 'human' | 'agent_initial' | 'agent_discussion';
  parent_reply_id?: string | null;
  discussion_round?: number;
}): Promise<Reply> {
  const visibility = input.visibility ?? 'public';
  const resolvedAuthorId =
    input.author_kind === 'agent'
      ? `agent-${input.agent_persona ?? 'unknown'}`
      : input.author_id ?? `guest-${randomUUID()}`;
  if (usingDB()) {
    const baseReplyPayload = {
      post_id: input.post_id,
      author_kind: input.author_kind,
      author_id: resolvedAuthorId,
      author_name: input.author_name,
      author_avatar: input.author_avatar ?? null,
      agent_persona: input.agent_persona ?? null,
      content: input.content,
      confidence_score: input.confidence_score ?? null,
      visibility,
    };
    const fullReplyPayload = {
      ...baseReplyPayload,
      is_autonomous: input.is_autonomous ?? false,
      reply_type: input.reply_type ?? (input.author_kind === 'human' ? 'human' : 'agent_initial'),
      parent_reply_id: input.parent_reply_id ?? null,
      discussion_round: input.discussion_round ?? 0,
    };

    let data: any = null;
    let error: any = null;

    ({ data, error } = await supabaseAdmin()
      .from('replies')
      .insert(fullReplyPayload)
      .select('*')
      .single());

    // Fallback: if is_autonomous column doesn't exist (migration 009 not yet run),
    // retry with base payload only so agent replies still work
    if (error) {
      const msg: string = error?.message ?? '';
      const isMissingCol = msg.includes('is_autonomous') || msg.includes('schema cache') ||
        (msg.includes('column') && msg.includes('not found'));
      if (isMissingCol) {
        ({ data, error } = await supabaseAdmin()
          .from('replies')
          .insert(baseReplyPayload)
          .select('*')
          .single());
      }
    }

    if (error) throw error;
    await supabaseAdmin().rpc('increment_post_reply', { p_id: input.post_id }).throwOnError().then(() => {}, () => {});
    return mapReply(data);
  }
  const r: Reply = {
    id: randomUUID(),
    post_id: input.post_id,
    author_kind: input.author_kind,
    author_id: resolvedAuthorId,
    author_name: input.author_name,
    author_avatar: input.author_avatar ?? null,
    agent_persona: input.agent_persona ?? null,
    content: input.content,
    created_at: new Date().toISOString(),
    confidence_score: input.confidence_score ?? null,
    visibility,
    up_count: 0,
    down_count: 0,
    is_autonomous: input.is_autonomous ?? false,
  };
  mem().replies.push(r);
  const post = mem().posts.find((p) => p.id === input.post_id);
  if (post) post.reply_count += 1;
  return r;
}

export async function enqueueReview(replyId: string, reason: string): Promise<void> {
  if (usingDB()) {
    await supabaseAdmin().from('review_queue').insert({ reply_id: replyId, reason, status: 'open' });
    return;
  }
  mem().review_queue.push({
    id: randomUUID(),
    reply_id: replyId,
    reason,
    status: 'open',
    created_at: new Date().toISOString(),
  });
}

export async function resolveReview(replyId: string, decision: 'approved' | 'rejected'): Promise<void> {
  if (usingDB()) {
    await supabaseAdmin().from('review_queue').update({ status: decision }).eq('reply_id', replyId);
    if (decision === 'approved') {
      await supabaseAdmin().from('replies').update({ visibility: 'public' }).eq('id', replyId);
    } else {
      await supabaseAdmin().from('replies').update({ visibility: 'hidden' }).eq('id', replyId);
    }
    return;
  }
  const item = mem().review_queue.find((x) => x.reply_id === replyId);
  if (item) item.status = decision;
  const reply = mem().replies.find((r) => r.id === replyId);
  if (reply) reply.visibility = decision === 'approved' ? 'public' : 'hidden';
}

// ===== Reactions =====

export async function react(replyId: string, userId: string, value: 1 | -1): Promise<Reply | null> {
  if (usingDB()) {
    await supabaseAdmin()
      .from('reactions')
      .upsert({ reply_id: replyId, user_id: userId, value }, { onConflict: 'reply_id,user_id' });
    await supabaseAdmin().rpc('recalc_reply_reactions', { r_id: replyId }).throwOnError();
    return await getReply(replyId);
  }
  const existing = mem().reactions.find((r) => r.reply_id === replyId && r.user_id === userId);
  if (existing) existing.value = value;
  else mem().reactions.push({ id: randomUUID(), reply_id: replyId, user_id: userId, value, created_at: new Date().toISOString() });
  const reply = mem().replies.find((r) => r.id === replyId);
  if (reply) {
    reply.up_count = mem().reactions.filter((r) => r.reply_id === replyId && r.value === 1).length;
    reply.down_count = mem().reactions.filter((r) => r.reply_id === replyId && r.value === -1).length;
  }
  return reply ?? null;
}

// ===== Listings =====

export async function listListings(filter?: { category?: string }): Promise<Listing[]> {
  if (usingDB()) {
    let q = supabaseAdmin().from('listings').select('*').order('created_at', { ascending: false }).limit(100);
    if (filter?.category) q = q.eq('category', filter.category);
    const { data, error } = await q;
    if (error) throw error;
    return (data ?? []).map(mapListing);
  }
  let items = [...mem().listings];
  if (filter?.category) items = items.filter((l) => l.category === filter.category);
  return items.sort((a, b) => b.created_at.localeCompare(a.created_at));
}

export async function getListing(id: string): Promise<Listing | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin().from('listings').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data ? mapListing(data) : null;
  }
  return mem().listings.find((l) => l.id === id) ?? null;
}

export async function createListing(input: Omit<Listing, 'id' | 'created_at' | 'bid_count' | 'top_bid_cents' | 'status'>): Promise<Listing> {
  if (usingDB()) {
    const payload: Record<string, unknown> = {
      seller_id: input.seller_id,
      seller_name: input.seller_name,
      seller_email: input.seller_email,
      seller_contact: input.seller_contact,
      category: input.category,
      title: input.title,
      description: input.description,
      asking_price_cents: input.asking_price_cents,
      currency: input.currency,
      location: input.location,
      images: input.images,
    };
    let { data, error } = await supabaseAdmin()
      .from('listings')
      .insert(payload)
      .select('*')
      .single();
    if (isMissingDbColumn(error, 'seller_contact')) {
      delete payload.seller_contact;
      const retry = await supabaseAdmin()
        .from('listings')
        .insert(payload)
        .select('*')
        .single();
      data = retry.data;
      error = retry.error;
    }
    if (error) throw error;
    return mapListing(data);
  }
  const l: Listing = {
    ...input,
    id: randomUUID(),
    status: 'open',
    created_at: new Date().toISOString(),
    bid_count: 0,
    top_bid_cents: null,
  };
  mem().listings.push(l);
  return l;
}

export async function updateListingStatus(id: string, status: Listing['status']): Promise<Listing | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('listings')
      .update({ status })
      .eq('id', id)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    return data ? mapListing(data) : null;
  }
  const l = mem().listings.find((x) => x.id === id);
  if (l) l.status = status;
  return l ?? null;
}

// ===== Bids =====

export async function listBids(listingId: string): Promise<Bid[]> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('bids')
      .select('*')
      .eq('listing_id', listingId)
      .order('amount_cents', { ascending: false });
    if (error) throw error;
    return (data ?? []).map(mapBid);
  }
  return mem()
    .bids.filter((b) => b.listing_id === listingId)
    .sort((a, b) => b.amount_cents - a.amount_cents);
}

export async function getBid(id: string): Promise<Bid | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin().from('bids').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data ? mapBid(data) : null;
  }
  return mem().bids.find((b) => b.id === id) ?? null;
}

export async function createBid(input: {
  listing_id: string;
  bidder_id?: string;
  bidder_name: string;
  bidder_email?: string | null;
  bidder_contact?: string | null;
  amount_cents: number;
  message?: string | null;
}): Promise<Bid | null> {
  const listing = await getListing(input.listing_id);
  if (!listing || listing.status !== 'open') return null;
  const bidderId = input.bidder_id ?? `guest-bidder-${randomUUID()}`;
  if (usingDB()) {
    const payload: Record<string, unknown> = {
      listing_id: input.listing_id,
      bidder_id: bidderId,
      bidder_name: input.bidder_name,
      bidder_email: input.bidder_email ?? null,
      bidder_contact: input.bidder_contact ?? null,
      amount_cents: input.amount_cents,
      message: input.message ?? null,
    };
    let { data, error } = await supabaseAdmin()
      .from('bids')
      .insert(payload)
      .select('*')
      .single();
    if (isMissingDbColumn(error, 'bidder_contact')) {
      delete payload.bidder_contact;
      const retry = await supabaseAdmin()
        .from('bids')
        .insert(payload)
        .select('*')
        .single();
      data = retry.data;
      error = retry.error;
    }
    if (error) throw error;
    return mapBid(data);
  }
  const b: Bid = {
    id: randomUUID(),
    listing_id: input.listing_id,
    bidder_id: bidderId,
    bidder_name: input.bidder_name,
    bidder_email: input.bidder_email ?? null,
    bidder_contact: input.bidder_contact ?? null,
    amount_cents: input.amount_cents,
    message: input.message ?? null,
    status: 'active',
    created_at: new Date().toISOString(),
  };
  mem().bids.push(b);
  const l = mem().listings.find((x) => x.id === input.listing_id);
  if (l) {
    l.bid_count += 1;
    if (l.top_bid_cents === null || input.amount_cents > l.top_bid_cents) l.top_bid_cents = input.amount_cents;
  }
  return b;
}

export async function acceptBid(bidId: string): Promise<{ transaction: Transaction; listing: Listing } | null> {
  const bid = await getBid(bidId);
  if (!bid) return null;
  const listing = await getListing(bid.listing_id);
  if (!listing || listing.status !== 'open') return null;

  if (usingDB()) {
    const payload: Record<string, unknown> = {
      listing_id: listing.id,
      winning_bid_id: bid.id,
      seller_id: listing.seller_id,
      buyer_id: bid.bidder_id,
      seller_name: listing.seller_name,
      buyer_name: bid.bidder_name,
      seller_email: listing.seller_email,
      buyer_email: bid.bidder_email,
      seller_contact: listing.seller_contact,
      buyer_contact: bid.bidder_contact,
      amount_cents: bid.amount_cents,
      status: 'pending',
    };
    let { data: tx, error: txErr } = await supabaseAdmin()
      .from('transactions')
      .insert(payload)
      .select('*')
      .single();
    if (
      isMissingDbColumn(txErr, 'seller_contact') ||
      isMissingDbColumn(txErr, 'buyer_contact') ||
      isMissingDbColumn(txErr, 'seller_email') ||
      isMissingDbColumn(txErr, 'buyer_email')
    ) {
      for (const column of ['seller_contact', 'buyer_contact', 'seller_email', 'buyer_email']) {
        delete payload[column];
      }
      const retry = await supabaseAdmin()
        .from('transactions')
        .insert(payload)
        .select('*')
        .single();
      tx = retry.data;
      txErr = retry.error;
    }
    if (txErr) throw txErr;
    await supabaseAdmin().from('bids').update({ status: 'accepted' }).eq('id', bid.id);
    await supabaseAdmin().from('bids').update({ status: 'rejected' }).eq('listing_id', listing.id).neq('id', bid.id).eq('status', 'active');
    await supabaseAdmin().from('listings').update({ status: 'pending' }).eq('id', listing.id);
    const updated = await getListing(listing.id);
    const transaction = {
      ...mapTransaction(tx),
      seller_email: listing.seller_email,
      buyer_email: bid.bidder_email,
      seller_contact: listing.seller_contact,
      buyer_contact: bid.bidder_contact,
    };
    return { transaction, listing: updated! };
  }
  const tx: Transaction = {
    id: randomUUID(),
    listing_id: listing.id,
    winning_bid_id: bid.id,
    seller_id: listing.seller_id,
    buyer_id: bid.bidder_id,
    seller_name: listing.seller_name,
    buyer_name: bid.bidder_name,
    seller_email: listing.seller_email,
    buyer_email: bid.bidder_email,
    seller_contact: listing.seller_contact,
    buyer_contact: bid.bidder_contact,
    amount_cents: bid.amount_cents,
    status: 'pending',
    created_at: new Date().toISOString(),
  };
  mem().transactions.push(tx);
  for (const b of mem().bids.filter((x) => x.listing_id === listing.id)) {
    b.status = b.id === bid.id ? 'accepted' : 'rejected';
  }
  const l = mem().listings.find((x) => x.id === listing.id);
  if (l) l.status = 'pending';
  return { transaction: tx, listing: l! };
}

export async function rollbackTradeConnection(input: { listingId: string; bidId: string; transactionId: string }) {
  if (usingDB()) {
    await supabaseAdmin().from('transactions').delete().eq('id', input.transactionId);
    await supabaseAdmin().from('bids').update({ status: 'active' }).eq('id', input.bidId);
    await supabaseAdmin().from('listings').update({ status: 'open' }).eq('id', input.listingId).eq('status', 'pending');
    return;
  }

  const db = mem();
  db.transactions = db.transactions.filter((tx) => tx.id !== input.transactionId);
  const bid = db.bids.find((b) => b.id === input.bidId);
  if (bid) bid.status = 'active';
  const listing = db.listings.find((l) => l.id === input.listingId);
  if (listing && listing.status === 'pending') listing.status = 'open';
}

// ===== Transactions & Messages =====

function mapTransaction(row: any): Transaction {
  return {
    id: row.id,
    listing_id: row.listing_id,
    winning_bid_id: row.winning_bid_id,
    seller_id: row.seller_id ?? '',
    buyer_id: row.buyer_id ?? '',
    seller_name: row.seller_name ?? 'Seller',
    buyer_name: row.buyer_name ?? 'Buyer',
    seller_email: row.seller_email ?? null,
    buyer_email: row.buyer_email ?? null,
    seller_contact: row.seller_contact ?? null,
    buyer_contact: row.buyer_contact ?? null,
    amount_cents: row.amount_cents,
    status: row.status,
    created_at: row.created_at,
  };
}
function mapMessage(row: any): Message {
  return {
    id: row.id,
    transaction_id: row.transaction_id,
    sender_id: row.sender_id ?? '',
    sender_name: row.sender_name ?? 'Anonymous',
    content: row.content,
    created_at: row.created_at,
  };
}

export async function getTransactionByListing(listingId: string): Promise<Transaction | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('transactions')
      .select('*')
      .eq('listing_id', listingId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data ? mapTransaction(data) : null;
  }
  return mem().transactions.find((t) => t.listing_id === listingId) ?? null;
}

export async function getTransaction(id: string): Promise<Transaction | null> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin().from('transactions').select('*').eq('id', id).maybeSingle();
    if (error) throw error;
    return data ? mapTransaction(data) : null;
  }
  return mem().transactions.find((t) => t.id === id) ?? null;
}

export async function canAccessTransaction(transactionId: string, userId: string, admin = false): Promise<boolean> {
  if (admin) return true;
  const transaction = await getTransaction(transactionId);
  return Boolean(transaction && (transaction.seller_id === userId || transaction.buyer_id === userId));
}

export async function listMessages(transactionId: string): Promise<Message[]> {
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('messages')
      .select('*')
      .eq('transaction_id', transactionId)
      .order('created_at', { ascending: true });
    if (error) throw error;
    return (data ?? []).map(mapMessage);
  }
  return mem().messages.filter((m) => m.transaction_id === transactionId);
}

// ================ Inbox / Transactions by user ================

export type TransactionSummary = Transaction & {
  listing_title: string;
  listing_category: string;
  last_message: string | null;
  last_message_at: string | null;
  unread_count: number;
};

export async function listTransactionsByUser(userId: string): Promise<TransactionSummary[]> {
  if (!usingDB()) {
    return mem().transactions
      .filter((t) => t.seller_id === userId || t.buyer_id === userId)
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
      .map((t) => ({
        ...t,
        listing_title: mem().listings.find((l) => l.id === t.listing_id)?.title ?? 'Listing',
        listing_category: mem().listings.find((l) => l.id === t.listing_id)?.category ?? 'other',
        last_message: null,
        last_message_at: null,
        unread_count: 0,
      }));
  }
  const { data: txns, error } = await supabaseAdmin()
    .from('transactions')
    .select('*')
    .or(`seller_id.eq.${userId},buyer_id.eq.${userId}`)
    .order('created_at', { ascending: false });
  if (error) throw error;
  if (!txns || txns.length === 0) return [];

  const results = await Promise.all(
    txns.map(async (tx: any) => {
      const [listing, msgs] = await Promise.all([
        supabaseAdmin().from('listings').select('title,category').eq('id', tx.listing_id).maybeSingle(),
        supabaseAdmin()
          .from('messages')
          .select('content,created_at,sender_id')
          .eq('transaction_id', tx.id)
          .order('created_at', { ascending: false })
          .limit(10),
      ]);
      const allMsgs = msgs.data ?? [];
      const lastMsg = allMsgs[0];
      const unread = allMsgs.filter(
        (m: any) => m.sender_id !== userId && m.sender_id !== 'system'
      ).length;
      return {
        ...mapTransaction(tx),
        listing_title: listing.data?.title ?? 'Listing',
        listing_category: listing.data?.category ?? 'other',
        last_message: lastMsg?.content?.slice(0, 80) ?? null,
        last_message_at: lastMsg?.created_at ?? null,
        unread_count: unread,
      };
    })
  );
  return results;
}

export async function getUnreadMessageCount(userId: string): Promise<number> {
  if (!usingDB()) return 0;
  const { data: txns } = await supabaseAdmin()
    .from('transactions')
    .select('id')
    .or(`seller_id.eq.${userId},buyer_id.eq.${userId}`);
  if (!txns || txns.length === 0) return 0;
  const ids = txns.map((t: any) => t.id);
  let total = 0;
  for (const txId of ids) {
    const { count } = await supabaseAdmin()
      .from('messages')
      .select('*', { count: 'exact', head: true })
      .eq('transaction_id', txId)
      .neq('sender_id', userId)
      .neq('sender_id', 'system');
    total += count ?? 0;
  }
  return total;
}

// ================ Notifications ================

function mapNotification(row: any): Notification {
  return {
    id: row.id,
    user_id: row.user_id,
    type: row.type as NotificationType,
    actor_name: row.actor_name ?? '',
    actor_avatar: row.actor_avatar ?? null,
    post_id: row.post_id ?? null,
    preview: row.preview ?? '',
    read: row.read ?? false,
    created_at: row.created_at,
  };
}

export async function createNotification(input: {
  user_id: string;
  type: NotificationType;
  actor_name: string;
  actor_avatar?: string | null;
  post_id?: string | null;
  preview: string;
}): Promise<void> {
  if (!usingDB()) return; // no-op in demo mode
  await supabaseAdmin()
    .from('notifications')
    .insert({
      user_id: input.user_id,
      type: input.type,
      actor_name: input.actor_name,
      actor_avatar: input.actor_avatar ?? null,
      post_id: input.post_id ?? null,
      preview: input.preview,
    });
}

export async function listNotifications(userId: string, limit = 20): Promise<Notification[]> {
  if (!usingDB()) return [];
  const { data, error } = await supabaseAdmin()
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) return [];
  return (data ?? []).map(mapNotification);
}

export async function getUnreadCount(userId: string): Promise<number> {
  if (!usingDB()) return 0;
  const { count, error } = await supabaseAdmin()
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('read', false);
  if (error) return 0;
  return count ?? 0;
}

export async function markNotificationRead(notificationId: string, userId?: string): Promise<void> {
  if (!usingDB()) return;
  let query = supabaseAdmin()
    .from('notifications')
    .update({ read: true })
    .eq('id', notificationId);
  if (userId) query = query.eq('user_id', userId);
  await query;
}

export async function markAllNotificationsRead(userId: string): Promise<void> {
  if (!usingDB()) return;
  await supabaseAdmin()
    .from('notifications')
    .update({ read: true })
    .eq('user_id', userId)
    .eq('read', false);
}

export async function createMessage(input: {
  transaction_id: string;
  sender_id?: string;
  sender_name: string;
  content: string;
}): Promise<Message> {
  const senderId = input.sender_id ?? `user-${Math.random().toString(36).slice(2, 8)}`;
  if (usingDB()) {
    const { data, error } = await supabaseAdmin()
      .from('messages')
      .insert({
        transaction_id: input.transaction_id,
        sender_id: senderId,
        sender_name: input.sender_name,
        content: input.content,
      })
      .select('*')
      .single();
    if (error) throw error;
    return mapMessage(data);
  }
  const m: Message = {
    id: randomUUID(),
    transaction_id: input.transaction_id,
    sender_id: senderId,
    sender_name: input.sender_name,
    content: input.content,
    created_at: new Date().toISOString(),
  };
  mem().messages.push(m);
  return m;
}

// ===== User Profiles (custom display names) =====

export async function getDisplayName(userId: string): Promise<string | null> {
  if (!usingDB()) return null;
  const { data } = await supabaseAdmin()
    .from('user_profiles')
    .select('display_name')
    .eq('user_id', userId)
    .single();
  return data?.display_name ?? null;
}

export async function setDisplayName(userId: string, displayName: string): Promise<void> {
  if (!usingDB()) return;
  await supabaseAdmin()
    .from('user_profiles')
    .upsert({ user_id: userId, display_name: displayName, updated_at: new Date().toISOString() });
}

// ===== Autonomous Agent Logs + Counters =====

export async function logAgentActivity(input: {
  agent_id: string;
  action_type: string;
  status: string;
  target_post_id?: string | null;
  created_post_id?: string | null;
  created_reply_id?: string | null;
  model?: string | null;
  generated_content?: string | null;
  quality_score?: number | null;
  token_input?: number | null;
  token_output?: number | null;
  estimated_cost?: number | null;
  latency_ms?: number | null;
  error_message?: string | null;
}): Promise<void> {
  if (!usingDB()) return;
  // fire-and-forget; don't await so callers aren't blocked
  Promise.resolve(
    supabaseAdmin().from('agent_activity_logs').insert(input)
  ).then(({ error }: any) => {
    if (error) console.warn('[agent-log]', error.message);
  }).catch((e: unknown) => console.warn('[agent-log] failed', e));
}

export async function getAgentDailyCount(agentId: string): Promise<{ auto_posts_count: number; auto_replies_count: number }> {
  if (!usingDB()) return { auto_posts_count: 0, auto_replies_count: 0 };
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabaseAdmin()
    .from('agent_daily_counters')
    .select('auto_posts_count, auto_replies_count')
    .eq('agent_id', agentId)
    .eq('date', today)
    .single();
  return { auto_posts_count: data?.auto_posts_count ?? 0, auto_replies_count: data?.auto_replies_count ?? 0 };
}

export async function incrementAgentDailyPost(agentId: string, costUsd = 0): Promise<void> {
  if (!usingDB()) return;
  const today = new Date().toISOString().slice(0, 10);
  try {
    // Try upsert: increment if row exists, insert if not
    const { data: existing } = await supabaseAdmin()
      .from('agent_daily_counters')
      .select('id, auto_posts_count, estimated_cost')
      .eq('agent_id', agentId)
      .eq('date', today)
      .single();
    if (existing) {
      await supabaseAdmin()
        .from('agent_daily_counters')
        .update({
          auto_posts_count: (existing.auto_posts_count ?? 0) + 1,
          estimated_cost: (existing.estimated_cost ?? 0) + costUsd,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id);
    } else {
      await supabaseAdmin()
        .from('agent_daily_counters')
        .insert({ agent_id: agentId, date: today, auto_posts_count: 1, estimated_cost: costUsd });
    }
  } catch (err) {
    console.warn('[agent-counter] failed', err);
  }
}

export async function getGlobalAutonomousStats(): Promise<{ today_posts: number; today_replies: number; today_cost: number }> {
  if (!usingDB()) return { today_posts: 0, today_replies: 0, today_cost: 0 };
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabaseAdmin()
    .from('agent_daily_counters')
    .select('auto_posts_count, auto_replies_count, estimated_cost')
    .eq('date', today);
  const rows = data ?? [];
  return {
    today_posts: rows.reduce((s, r) => s + (r.auto_posts_count ?? 0), 0),
    today_replies: rows.reduce((s, r) => s + (r.auto_replies_count ?? 0), 0),
    today_cost: rows.reduce((s, r) => s + (r.estimated_cost ?? 0), 0),
  };
}

export async function incrementAgentDailyReply(agentId: string, costUsd = 0): Promise<void> {
  if (!usingDB()) return;
  const today = new Date().toISOString().slice(0, 10);
  try {
    const { data: existing } = await supabaseAdmin()
      .from('agent_daily_counters')
      .select('id, auto_replies_count, estimated_cost')
      .eq('agent_id', agentId)
      .eq('date', today)
      .single();
    if (existing) {
      await supabaseAdmin()
        .from('agent_daily_counters')
        .update({
          auto_replies_count: (existing.auto_replies_count ?? 0) + 1,
          estimated_cost: (existing.estimated_cost ?? 0) + costUsd,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id);
    } else {
      await supabaseAdmin()
        .from('agent_daily_counters')
        .insert({ agent_id: agentId, date: today, auto_replies_count: 1, estimated_cost: costUsd });
    }
  } catch (err) {
    console.warn('[agent-counter-reply] failed', err);
  }
}

export type AgentActivityLog = {
  id: string;
  agent_id: string;
  action_type: string;
  status: string;
  generated_content: string | null;
  model: string | null;
  estimated_cost: number | null;
  latency_ms: number | null;
  error_message: string | null;
  created_at: string;
  created_post_id: string | null;
  created_reply_id: string | null;
};

export async function listAgentActivityLogs(limit = 30): Promise<AgentActivityLog[]> {
  if (!usingDB()) return [];
  const { data } = await supabaseAdmin()
    .from('agent_activity_logs')
    .select('id,agent_id,action_type,status,generated_content,model,estimated_cost,latency_ms,error_message,created_at,created_post_id,created_reply_id')
    .order('created_at', { ascending: false })
    .limit(limit);
  return (data ?? []) as AgentActivityLog[];
}

// Count how many agent replies exist on a given post
export async function countAgentRepliesOnPost(postId: string): Promise<number> {
  if (!usingDB()) return 0;
  const { count } = await supabaseAdmin()
    .from('replies')
    .select('*', { count: 'exact', head: true })
    .eq('post_id', postId)
    .eq('author_kind', 'agent')
    .eq('is_autonomous', true) as any;
  return count ?? 0;
}

// Get reply count breakdown for target selection
export async function getPostReplyStats(postId: string): Promise<{ total: number; agentCount: number; autonomousCount: number }> {
  if (!usingDB()) return { total: 0, agentCount: 0, autonomousCount: 0 };
  const replies = await listReplies(postId);
  return {
    total: replies.length,
    agentCount: replies.filter((r) => r.author_kind === 'agent').length,
    autonomousCount: replies.filter((r) => r.is_autonomous === true).length,
  };
}

// ===== Agent Discussion Engine helpers =====

export async function getDiscussionRoundForPost(postId: string): Promise<number> {
  if (!usingDB()) return 0;
  const { data } = await supabaseAdmin()
    .from('agent_discussion_jobs')
    .select('round')
    .eq('post_id', postId)
    .eq('status', 'completed')
    .order('round', { ascending: false })
    .limit(1)
    .single();
  return data?.round ?? 0;
}

export async function countAgentDiscussionReplies(postId: string): Promise<number> {
  if (!usingDB()) return 0;
  const { count } = await supabaseAdmin()
    .from('replies')
    .select('*', { count: 'exact', head: true })
    .eq('post_id', postId)
    .eq('author_kind', 'agent') as any;
  return count ?? 0;
}

export async function isDiscussionJobRunning(postId: string): Promise<boolean> {
  if (!usingDB()) return false;
  const { data } = await supabaseAdmin()
    .from('agent_discussion_jobs')
    .select('id')
    .eq('post_id', postId)
    .in('status', ['queued', 'running'])
    .limit(1)
    .single();
  return !!data;
}

export async function createDiscussionJob(postId: string, round: number): Promise<string | null> {
  if (!usingDB()) return null;
  const { data } = await supabaseAdmin()
    .from('agent_discussion_jobs')
    .insert({ post_id: postId, round, status: 'running', started_at: new Date().toISOString() })
    .select('id')
    .single();
  return data?.id ?? null;
}

export async function finishDiscussionJob(
  jobId: string,
  status: 'completed' | 'failed' | 'skipped',
  opts: { inserted?: number; error?: string } = {}
): Promise<void> {
  if (!usingDB() || !jobId) return;
  await supabaseAdmin()
    .from('agent_discussion_jobs')
    .update({
      status,
      replies_inserted: opts.inserted ?? 0,
      finished_at: new Date().toISOString(),
      error_message: opts.error ?? null,
    })
    .eq('id', jobId);
}

export async function getHourlyDiscussionCount(): Promise<number> {
  if (!usingDB()) return 0;
  const oneHourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const { count } = await supabaseAdmin()
    .from('agent_discussion_jobs')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'completed')
    .gte('finished_at', oneHourAgo) as any;
  return count ?? 0;
}

export async function getRecentHotPosts(limit = 10): Promise<Post[]> {
  if (!usingDB()) return [];
  const yesterday = new Date(Date.now() - 86_400_000).toISOString();
  const { data } = await supabaseAdmin()
    .from('posts')
    .select('*')
    .gte('created_at', yesterday)
    .order('reply_count', { ascending: false })
    .limit(limit);
  return (data ?? []).map(mapPost);
}
