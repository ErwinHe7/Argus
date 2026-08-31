'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Loader2, Link as LinkIcon } from 'lucide-react';

const TAG_SUGGESTIONS = [
  'free', 'columbia', 'nyc', 'party', 'networking', 'music', 'art',
  'food', 'outdoor', 'tech', 'academic', 'film', 'social', 'sports',
];

export default function SubmitEventPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    title: '',
    url: '',
    start_time: '',
    end_time: '',
    location: '',
    description: '',
    poster_url: '',
    price_text: '',
    is_free: false,
  });
  const [tags, setTags] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [scraping, setScraping] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  async function scrapeUrl() {
    if (!form.url.trim()) return;
    setScraping(true);
    try {
      // Just try to prefill from og: tags via our submit endpoint
      const res = await fetch('/api/events/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: 'preview', url: form.url }),
      });
      // We don't actually commit here — this is just a hint for the user
      // The actual scrape happens server-side on final submit
    } catch {}
    setScraping(false);
  }

  function toggleTag(tag: string) {
    setTags((prev) =>
      prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag]
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.title.trim()) { setError('Title is required.'); return; }
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/events/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: form.title.trim(),
          url: form.url.trim() || undefined,
          start_time: form.start_time || undefined,
          end_time: form.end_time || undefined,
          location: form.location.trim() || undefined,
          description: form.description.trim() || undefined,
          poster_url: form.poster_url.trim() || undefined,
          price_text: form.price_text.trim() || undefined,
          is_free: form.is_free || undefined,
          tags,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) { setError(data.error ?? 'Submission failed.'); return; }
      setSuccess(true);
    } finally {
      setLoading(false);
    }
  }

  const inputCls = 'w-full rounded-lg px-3 py-2 text-sm focus:outline-none';
  const inputStyle = {
    background: 'rgba(0,0,0,0.04)',
    border: '1px solid var(--lt-border)',
    color: 'var(--lt-text)',
    caretColor: 'var(--molt-shell)',
  } as React.CSSProperties;

  if (success) {
    return (
      <div
        className="min-h-screen flex items-center justify-center px-4"
        style={{ background: 'var(--lt-bg)' }}
      >
        <div className="max-w-sm text-center space-y-4">
          <div className="text-5xl">🎉</div>
          <h2 className="text-xl font-semibold" style={{ color: 'var(--lt-text)' }}>
            Event submitted!
          </h2>
          <p className="text-sm" style={{ color: 'var(--lt-muted)' }}>
            Your event is under review and will appear on the Events page once approved.
          </p>
          <div className="flex justify-center gap-3">
            <Link
              href="/events"
              className="rounded-xl px-4 py-2 text-sm font-semibold text-white"
              style={{ background: 'var(--molt-shell)' }}
            >
              Browse Events →
            </Link>
            <button
              onClick={() => setSuccess(false)}
              className="rounded-xl px-4 py-2 text-sm font-medium"
              style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)', color: 'var(--lt-text)' }}
            >
              Submit another
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen px-4 py-10" style={{ background: 'var(--lt-bg)' }}>
      <div className="mx-auto max-w-xl space-y-6">
        <Link
          href="/events"
          className="inline-flex items-center gap-1 text-sm hover:opacity-80"
          style={{ color: 'var(--lt-muted)' }}
        >
          <ArrowLeft className="h-4 w-4" /> Back to Events
        </Link>

        <div>
          <h1 className="text-2xl font-semibold" style={{ color: 'var(--lt-text)' }}>Submit an event</h1>
          <p className="mt-1 text-sm" style={{ color: 'var(--lt-muted)' }}>
            Share a Columbia or NYC event with the community. It will appear after review.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 rounded-[22px] p-5"
          style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>

          {/* URL + auto-fill */}
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>
              Event link (optional)
            </label>
            <div className="flex gap-2">
              <input
                type="url"
                value={form.url}
                onChange={(e) => setForm({ ...form, url: e.target.value })}
                placeholder="https://..."
                className={`${inputCls} flex-1`}
                style={inputStyle}
              />
              <button
                type="button"
                onClick={scrapeUrl}
                disabled={!form.url.trim() || scraping}
                className="inline-flex items-center gap-1 rounded-lg px-3 py-2 text-xs font-medium text-white transition hover:opacity-90 disabled:opacity-40"
                style={{ background: 'var(--molt-shell)' }}
              >
                {scraping ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <LinkIcon className="h-3.5 w-3.5" />}
                Auto-fill
              </button>
            </div>
          </div>

          {/* Title */}
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>
              Title <span style={{ color: 'var(--molt-coral)' }}>*</span>
            </label>
            <input
              required
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              placeholder="Columbia Startup Demo Day"
              className={inputCls}
              style={inputStyle}
            />
          </div>

          {/* Date/time */}
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>Start</label>
              <input type="datetime-local" value={form.start_time} onChange={(e) => setForm({ ...form, start_time: e.target.value })}
                className={inputCls} style={inputStyle} />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>End</label>
              <input type="datetime-local" value={form.end_time} onChange={(e) => setForm({ ...form, end_time: e.target.value })}
                className={inputCls} style={inputStyle} />
            </div>
          </div>

          {/* Location */}
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>Location</label>
            <input
              value={form.location}
              onChange={(e) => setForm({ ...form, location: e.target.value })}
              placeholder="Lerner Hall, Columbia University"
              className={inputCls}
              style={inputStyle}
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>Description</label>
            <textarea
              rows={3}
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              placeholder="What is this event about?"
              className={inputCls}
              style={inputStyle}
            />
          </div>

          {/* Price */}
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>Price</label>
              <input
                value={form.price_text}
                onChange={(e) => setForm({ ...form, price_text: e.target.value })}
                placeholder="Free / $10 / Pay what you wish"
                className={inputCls}
                style={inputStyle}
              />
            </div>
            <div className="flex items-end pb-2">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.is_free}
                  onChange={(e) => setForm({ ...form, is_free: e.target.checked })}
                  className="h-4 w-4 rounded"
                  style={{ accentColor: 'var(--molt-shell)' }}
                />
                <span className="text-sm" style={{ color: 'var(--lt-text)' }}>Free event</span>
              </label>
            </div>
          </div>

          {/* Poster URL */}
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--lt-text)' }}>
              Poster image URL (optional)
            </label>
            <input
              type="url"
              value={form.poster_url}
              onChange={(e) => setForm({ ...form, poster_url: e.target.value })}
              placeholder="https://..."
              className={inputCls}
              style={inputStyle}
            />
          </div>

          {/* Tags */}
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: 'var(--lt-text)' }}>Tags</label>
            <div className="flex flex-wrap gap-2">
              {TAG_SUGGESTIONS.map((tag) => (
                <button
                  key={tag}
                  type="button"
                  onClick={() => toggleTag(tag)}
                  className="rounded-full px-3 py-1 text-xs font-medium transition hover:opacity-80"
                  style={tags.includes(tag) ? {
                    background: 'var(--molt-shell)', color: 'white',
                  } : {
                    background: 'rgba(0,0,0,0.06)', color: 'var(--lt-muted)',
                    border: '1px solid var(--lt-border)',
                  }}
                >
                  {tag}
                </button>
              ))}
            </div>
          </div>

          {error && (
            <div className="rounded-lg px-3 py-2 text-sm" style={{ background: 'rgba(220,38,38,0.08)', border: '1px solid rgba(220,38,38,0.2)', color: '#dc2626' }}>
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="inline-flex w-full items-center justify-center gap-2 rounded-xl px-4 py-3 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50"
            style={{ background: 'var(--molt-shell)' }}
          >
            {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            Submit for review
          </button>
        </form>
      </div>
    </div>
  );
}
