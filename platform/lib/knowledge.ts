import { supabaseAdmin, isSupabaseConfigured } from './supabase';

// Knowledge layer: stores short context chunks from posts/replies/listings
// so agents can retrieve them when drafting a new reply.
// - If TokenRouter supports /embeddings, we could later do vector search.
// - Default path uses Postgres full-text search (search_chunks RPC).

export async function upsertChunk(input: {
  source_kind: 'post' | 'reply' | 'listing' | 'manual';
  source_id?: string | null;
  content: string;
}): Promise<void> {
  if (!isSupabaseConfigured()) return;
  try {
    await supabaseAdmin().from('knowledge_chunks').insert({
      source_kind: input.source_kind,
      source_id: input.source_id ?? null,
      content: input.content.slice(0, 2000),
    });
  } catch {
    // best-effort; knowledge search is non-critical
  }
}

export async function searchRelevant(query: string, limit = 3): Promise<string[]> {
  if (!isSupabaseConfigured()) return [];
  try {
    const { data } = await supabaseAdmin().rpc('search_chunks', { q: query, lim: limit });
    return (data ?? []).map((r: any) => r.content).filter(Boolean);
  } catch {
    return [];
  }
}
