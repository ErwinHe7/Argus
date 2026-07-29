export type EventStatus = 'pending' | 'published' | 'rejected' | 'expired';

export type EventSource = {
  id: string;
  name: string;
  kind: 'api' | 'rss' | 'ical' | 'html' | 'user_submit' | 'manual';
  url: string | null;
  trust_score: number;
  refresh_interval_minutes: number;
  enabled: boolean;
  last_synced_at: string | null;
  created_at: string;
};

export type Event = {
  id: string;
  source_id: string | null;
  external_id: string | null;
  title: string;
  description: string | null;
  start_time: string | null;
  end_time: string | null;
  location: string | null;
  borough: string | null;
  lat: number | null;
  lng: number | null;
  url: string | null;
  poster_url: string | null;
  tags: string[];
  category: string | null;
  price_text: string | null;
  is_free: boolean | null;
  submitted_by_author_id: string | null;
  status: EventStatus;
  freshness_score: number;
  created_at: string;
  updated_at: string;
};

// Used during normalization / ingestion before DB insert
export type NormalizedEvent = {
  external_id: string;
  title: string;
  description: string | null;
  start_time: string | null;
  end_time: string | null;
  location: string | null;
  borough: string | null;
  lat: number | null;
  lng: number | null;
  url: string | null;
  poster_url: string | null;
  tags: string[];
  category: string | null;
  price_text: string | null;
  is_free: boolean | null;
  raw_payload: Record<string, unknown>;
};

export type IngestSourceResult = {
  name: string;
  inserted: number;
  updated: number;
  skipped: number;
  error: string | null;
};
