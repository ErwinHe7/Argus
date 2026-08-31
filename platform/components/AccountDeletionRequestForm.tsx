'use client';

import { useState } from 'react';
import { AlertTriangle, CheckCircle2, Loader2 } from 'lucide-react';

export function AccountDeletionRequestForm() {
  const [notes, setNotes] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ id?: string; duplicate?: boolean } | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!confirmed) return;
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const res = await fetch('/api/account/deletion-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ notes }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error ?? 'Failed to request account deletion');
      setResult({ id: data?.request?.id, duplicate: Boolean(data?.duplicate) });
    } catch (err: any) {
      setError(err?.message ?? 'Failed to request account deletion');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4 rounded-[22px] border p-5" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
      <label className="block space-y-2 text-sm" style={{ color: 'var(--lt-muted)' }}>
        Optional notes for support
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={4}
          maxLength={1000}
          placeholder="Tell us if there is research history or other account data you especially want removed or anonymized."
          className="w-full rounded-xl border px-3 py-2 text-sm outline-none"
          style={{ borderColor: 'var(--lt-border)', background: 'var(--lt-panel)', color: 'var(--lt-text)' }}
        />
      </label>

      <label className="flex gap-3 rounded-xl border p-3 text-sm" style={{ borderColor: 'var(--lt-border)', color: 'var(--lt-muted)' }}>
        <input type="checkbox" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} className="mt-1 accent-red-500" />
        <span>I understand Leo will review this request and delete or anonymize account data where possible, while limited safety, fraud-prevention, legal, or dispute records may be retained.</span>
      </label>

      <button
        type="submit"
        disabled={!confirmed || busy || Boolean(result)}
        className="inline-flex items-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-700 disabled:opacity-50"
      >
        {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <AlertTriangle className="h-4 w-4" />}
        Request account deletion
      </button>

      {error && <div className="rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div>}
      {result && (
        <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-800">
          <CheckCircle2 className="mr-2 inline h-4 w-4" />
          {result.duplicate ? 'You already have an active deletion request.' : 'Deletion request received.'} Support will process it and follow up by email when needed.
        </div>
      )}
    </form>
  );
}
