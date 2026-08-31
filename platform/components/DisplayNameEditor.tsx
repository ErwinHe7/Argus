'use client';

import { useState, useEffect } from 'react';
import { Pencil, Check, X, Loader2 } from 'lucide-react';

export function DisplayNameEditor() {
  const [current, setCurrent] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [saving, setSaving] = useState(false);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    fetch('/api/profile/display-name')
      .then(r => r.json())
      .then(d => { setCurrent(d.displayName); setLoaded(true); })
      .catch(() => setLoaded(true));
  }, []);

  async function save() {
    if (!draft.trim()) return;
    setSaving(true);
    try {
      const res = await fetch('/api/profile/display-name', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ displayName: draft.trim() }),
      });
      const data = await res.json();
      if (data.ok) { setCurrent(data.displayName); setEditing(false); }
    } finally { setSaving(false); }
  }

  if (!loaded) return null;

  return (
    <div className="mt-3">
      <p className="text-xs font-semibold uppercase tracking-wider mb-1" style={{ color: 'var(--lt-subtle)' }}>
        Display name
      </p>
      {editing ? (
        <div className="flex items-center gap-2">
          <input
            value={draft}
            onChange={e => setDraft(e.target.value)}
            maxLength={40}
            autoFocus
            onKeyDown={e => { if (e.key === 'Enter') save(); if (e.key === 'Escape') setEditing(false); }}
            placeholder="Your display name"
            className="rounded-lg border px-3 py-1.5 text-sm focus:outline-none"
            style={{ borderColor: 'var(--lt-border)', color: 'var(--lt-text)', background: 'var(--lt-surface)', width: 200 }}
          />
          <button onClick={save} disabled={saving || !draft.trim()}
            className="rounded-lg p-1.5 transition hover:opacity-80 disabled:opacity-40"
            style={{ background: 'var(--molt-shell)', color: 'white' }}>
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
          </button>
          <button onClick={() => setEditing(false)}
            className="rounded-lg p-1.5 transition hover:opacity-70"
            style={{ color: 'var(--lt-muted)' }}>
            <X className="h-4 w-4" />
          </button>
        </div>
      ) : (
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium" style={{ color: current ? 'var(--lt-text)' : 'var(--lt-subtle)' }}>
            {current ?? 'Not set'}
          </span>
          <button
            onClick={() => { setDraft(current ?? ''); setEditing(true); }}
            className="rounded p-0.5 transition hover:opacity-70"
            style={{ color: 'var(--lt-muted)' }}
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
        </div>
      )}
      <p className="mt-1 text-[11px]" style={{ color: 'var(--lt-subtle)' }}>
        This replaces your name on all new posts
      </p>
    </div>
  );
}
