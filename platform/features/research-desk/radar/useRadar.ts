import { useEffect, useRef, useState } from 'react';
import { assertRadarMonotonic, validateRadarIntegrity, type EventRadar } from './contract';

export async function readRadar(response: Response): Promise<EventRadar> {
  if (!response.ok || !response.body) throw new Error('Radar is unavailable');
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = []; let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read(); if (done) break;
      length += value.byteLength;
      if (length > 524288) { await reader.cancel(); throw new Error('Radar response exceeds its limit'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return validateRadarIntegrity(JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)));
}

export function useRadar() {
  const [data, setData] = useState<EventRadar | null>(null);
  const [error, setError] = useState(''), [loading, setLoading] = useState(true), [revision, setRevision] = useState(0);
  const [now, setNow] = useState(Date.now);
  const retained = useRef<EventRadar | null>(null);
  useEffect(() => {
    let alive = true, busy = false, controller: AbortController | undefined;
    async function refresh() {
      if (busy) return; busy = true; controller = new AbortController();
      const timer = setTimeout(() => controller?.abort(), 12000);
      if (alive) setLoading(true);
      try {
        const value = await readRadar(await fetch('/app/research-desk/data/event-radar.json', { cache: 'no-store', signal: controller.signal }));
        if (alive) {
          if (retained.current) assertRadarMonotonic(retained.current, value);
          retained.current = value;
          setData(value);
          setError('');
        }
      } catch { if (alive) setError('Calendar refresh failed. Retained dates need checking with the source.'); }
      finally { clearTimeout(timer); busy = false; if (alive) { setLoading(false); setNow(Date.now()); } }
    }
    void refresh();
    const tick = () => { setNow(Date.now()); if (document.visibilityState === 'visible') void refresh(); };
    const visible = () => { if (document.visibilityState === 'visible') tick(); };
    const interval = setInterval(tick, 60000);
    document.addEventListener('visibilitychange', visible);
    return () => { alive = false; controller?.abort(); clearInterval(interval); document.removeEventListener('visibilitychange', visible); };
  }, [revision]);
  return { data, error, loading, now, refresh: () => setRevision(value => value + 1) };
}

export const etDate = (now: number) => new Date(now).toLocaleDateString('en-CA', { timeZone: 'America/New_York' });
export const dateLabel = (value: string) => new Date(`${value}T12:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
export const timeLabel = (value: string) => `${new Date(value).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZone: 'America/New_York' })} ET`;
export type RadarEvent = EventRadar['events'][number];
export function eventUpcoming(event: RadarEvent, now: number) { return event.scheduledAt ? Date.parse(event.scheduledAt) > now : event.endDate >= etDate(now); }
export function eventTime(event: RadarEvent) { return event.scheduledAt ? timeLabel(event.scheduledAt) : `${dateLabel(event.startDate)}${event.endDate !== event.startDate ? ` – ${dateLabel(event.endDate)}` : ''} · time unconfirmed`; }
export function eventDay(event: RadarEvent) { return event.scheduledAt ? etDate(Date.parse(event.scheduledAt)) : event.startDate; }
export function eventOrder(event: RadarEvent) { return event.scheduledAt ?? `${event.startDate}T00:00:00Z`; }
export function sourceCurrent(data: EventRadar, event: RadarEvent, now: number) {
  const source = data.sources.find(item => item.id === event.sourceId);
  return !!source && source.state === 'success' && !!source.reviewAfter && Date.parse(source.reviewAfter) > now;
}
