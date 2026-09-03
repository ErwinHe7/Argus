import { supabaseAdmin } from '../supabase';
import { isSupabaseConfigured } from '../supabase';
import type { IngestSourceResult, NormalizedEvent } from './types';
import { fetchColumbiaEvents } from './sources/columbia';
import { fetchNycOpenDataEvents } from './sources/nycOpenData';
import { fetchTicketmasterEvents } from './sources/ticketmaster';

async function upsertEvents(
  sourceId: string,
  events: NormalizedEvent[]
): Promise<{ inserted: number; updated: number; skipped: number }> {
  let inserted = 0;
  let updated = 0;
  let skipped = 0;

  for (const ev of events) {
    // Skip if start_time is in the past
    if (ev.start_time && new Date(ev.start_time).getTime() < Date.now()) {
      skipped++;
      continue;
    }

    const { data: existing } = await supabaseAdmin()
      .from('events')
      .select('id, title')
      .eq('source_id', sourceId)
      .eq('external_id', ev.external_id)
      .maybeSingle();

    if (existing) {
      await supabaseAdmin()
        .from('events')
        .update({
          title: ev.title,
          description: ev.description,
          start_time: ev.start_time,
          end_time: ev.end_time,
          location: ev.location,
          borough: ev.borough,
          lat: ev.lat,
          lng: ev.lng,
          url: ev.url,
          poster_url: ev.poster_url,
          tags: ev.tags,
          category: ev.category,
          price_text: ev.price_text,
          is_free: ev.is_free,
          raw_payload: ev.raw_payload,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id);
      updated++;
    } else {
      const { error } = await supabaseAdmin().from('events').insert({
        source_id: sourceId,
        external_id: ev.external_id,
        title: ev.title,
        description: ev.description,
        start_time: ev.start_time,
        end_time: ev.end_time,
        location: ev.location,
        borough: ev.borough,
        lat: ev.lat,
        lng: ev.lng,
        url: ev.url,
        poster_url: ev.poster_url,
        tags: ev.tags,
        category: ev.category,
        price_text: ev.price_text,
        is_free: ev.is_free,
        raw_payload: ev.raw_payload,
        status: 'published',
      });
      if (error) {
        // unique constraint violation = already exists under different source
        if (error.code === '23505') skipped++;
        else throw error;
      } else {
        inserted++;
      }
    }
  }

  return { inserted, updated, skipped };
}

async function markExpired(): Promise<number> {
  const yesterday = new Date(Date.now() - 86_400_000).toISOString();
  const { count } = await supabaseAdmin()
    .from('events')
    .update({ status: 'expired' })
    .lt('end_time', yesterday)
    .eq('status', 'published')
    .select('id');
  return count ?? 0;
}

async function getSourceId(name: string): Promise<string | null> {
  const { data } = await supabaseAdmin()
    .from('event_sources')
    .select('id')
    .eq('name', name)
    .eq('enabled', true)
    .maybeSingle();
  return data?.id ?? null;
}

async function markSynced(sourceId: string) {
  await supabaseAdmin()
    .from('event_sources')
    .update({ last_synced_at: new Date().toISOString() })
    .eq('id', sourceId);
}

export async function ingestAll(): Promise<IngestSourceResult[]> {
  if (!isSupabaseConfigured()) {
    return [{ name: 'all', inserted: 0, updated: 0, skipped: 0, error: 'Supabase not configured' }];
  }

  const results: IngestSourceResult[] = [];

  // Mark expired events first
  await markExpired().catch(() => {});

  // Columbia iCal
  {
    const name = 'Columbia Events Calendar';
    const sourceId = await getSourceId(name);
    if (sourceId) {
      try {
        const events = await fetchColumbiaEvents();
        const counts = await upsertEvents(sourceId, events);
        await markSynced(sourceId);
        results.push({ name, ...counts, error: null });
      } catch (err: unknown) {
        results.push({ name, inserted: 0, updated: 0, skipped: 0, error: String(err) });
      }
    }
  }

  // NYC Open Data
  {
    const name = 'NYC Open Data — Permitted Events';
    const sourceId = await getSourceId(name);
    if (sourceId) {
      try {
        const events = await fetchNycOpenDataEvents();
        const counts = await upsertEvents(sourceId, events);
        await markSynced(sourceId);
        results.push({ name, ...counts, error: null });
      } catch (err: unknown) {
        results.push({ name, inserted: 0, updated: 0, skipped: 0, error: String(err) });
      }
    }
  }

  // Ticketmaster
  {
    const name = 'Ticketmaster Discovery NYC';
    const sourceId = await getSourceId(name);
    if (sourceId) {
      try {
        const events = await fetchTicketmasterEvents();
        const counts = await upsertEvents(sourceId, events);
        await markSynced(sourceId);
        results.push({ name, ...counts, error: null });
      } catch (err: unknown) {
        results.push({ name, inserted: 0, updated: 0, skipped: 0, error: String(err) });
      }
    }
  }

  return results;
}
