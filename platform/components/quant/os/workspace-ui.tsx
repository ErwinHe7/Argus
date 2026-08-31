import type { ReactNode } from 'react';
import { Activity, AlertTriangle, ArrowRight, CheckCircle2, Search, ShieldCheck } from 'lucide-react';
import type { NativeJsonRecord, NativeResourceEnvelope } from '@/lib/quant/native-os-types';

export type Json = NativeJsonRecord;

export function Workspace({ title, eyebrow, description, children }: { title: string; eyebrow: string; description: string; children: ReactNode }) {
  return <div className="space-y-5"><div><p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-[#85888d]">{eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-[-0.045em] text-[#111315] sm:text-4xl">{title}</h1><p className="mt-3 max-w-4xl text-sm leading-6 text-[#65686e]">{description}</p></div>{children}</div>;
}

export function AvailabilityBanner({ payload, expected }: { payload: Json; expected: string }) {
  const status = resourceStatus(payload);
  const message = text(first(payload, ['message', 'reason', 'detail', 'truth']));
  const unavailable = isUnavailable(payload);
  const style = unavailable ? 'border-[#e7d2b2] bg-[#fff9ef] text-[#72552c]' : /DEGRADED|WARN/i.test(status) ? 'border-[#e2c3b9] bg-[#fff6f2] text-[#82483e]' : 'border-[#cdded5] bg-[#f4faf6] text-[#315f4e]';
  return <div className={`flex flex-wrap items-start justify-between gap-3 rounded-xl border p-4 ${style}`}><div className="flex min-w-0 gap-3">{unavailable ? <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" /> : <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />}<div><p className="text-xs font-semibold uppercase tracking-[0.09em]">{status}</p><p className="mt-1 text-xs leading-5">{message || (unavailable ? 'Backend has not produced this research artifact yet.' : 'Endpoint responded with a structured evidence payload.')}</p></div></div><code className="rounded bg-white/60 px-2 py-1 text-[10px]">{expected}</code></div>;
}

export function DecisionBanner({ title, detail }: { title: string; detail: string }) {
  return <div className="rounded-xl border border-[#e4c7a0] bg-[#fff8ec] p-4 text-[#765323]"><p className="text-sm font-semibold">{title}</p><p className="mt-1 text-xs leading-5">{detail}</p></div>;
}

export function MetricGrid({ children }: { children: ReactNode }) { return <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">{children}</div>; }

export function Metric({ label, value, note }: { label: string; value: ReactNode; note?: ReactNode }) {
  return <div className="rounded-xl border border-[#d9d9d5] bg-white p-4"><p className="text-[10px] font-medium uppercase tracking-[0.11em] text-[#92959a]">{label}</p><p className="mt-2 break-words font-mono text-xl font-semibold tracking-[-0.03em] text-[#1f2123]">{value || '—'}</p>{note ? <p className="mt-1.5 break-words text-[10px] leading-4 text-[#8a8d92]">{note}</p> : null}</div>;
}

export function Section({ title, subtitle, icon: Icon, children }: { title: string; subtitle?: string; icon: typeof Activity; children: ReactNode }) {
  return <section className="rounded-2xl border border-[#d9d9d5] bg-white p-5 sm:p-6"><div className="mb-5 flex items-start gap-3"><div className="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-[#f1f2ef] text-[#4f5b56]"><Icon className="h-4 w-4" /></div><div><h2 className="font-semibold tracking-[-0.01em] text-[#202224]">{title}</h2>{subtitle ? <p className="mt-1 text-xs leading-5 text-[#85888d]">{subtitle}</p> : null}</div></div>{children}</section>;
}

export function TwoColumn({ children }: { children: ReactNode }) { return <div className="grid gap-5 xl:grid-cols-2">{children}</div>; }
export function ThreeColumn({ children }: { children: ReactNode }) { return <div className="grid gap-5 lg:grid-cols-3">{children}</div>; }

export function KeyValueGrid({ items }: { items: Array<[string, unknown]> }) {
  return <dl className="grid gap-x-6 gap-y-4 sm:grid-cols-2">{items.map(([label, value]) => <div key={label} className="min-w-0 border-b border-[#eeeeea] pb-3"><dt className="text-[10px] uppercase tracking-[0.09em] text-[#96999d]">{label}</dt><dd className="mt-1.5 break-words font-mono text-xs text-[#34373a]">{display(value)}</dd></div>)}</dl>;
}

export function FeatureStrip({ title, values, empty, fallback }: { title: string; values: string[]; empty?: string; fallback?: string[] }) {
  const shown = values.length ? values : fallback || [];
  return <div className="mt-4 first:mt-0"><p className="text-[10px] font-medium uppercase tracking-[0.1em] text-[#92959a]">{title}</p>{shown.length ? <div className="mt-2 flex flex-wrap gap-2">{shown.map((value) => <span key={value} className="rounded-full border border-[#deded9] bg-[#f7f7f4] px-2.5 py-1 text-[10px] text-[#5e6165]">{value}</span>)}</div> : <p className="mt-2 text-xs leading-5 text-[#96999d]">{empty || 'No values reported.'}</p>}</div>;
}

export function DataTable({ columns, rows: tableRows, empty }: { columns: string[]; rows: ReactNode[][]; empty: string }) {
  if (!tableRows.length) return <EmptyDetail text={empty} />;
  return <div className="overflow-x-auto rounded-xl border border-[#e1e1dc]"><table className="w-full min-w-[980px] text-left text-[11px]"><thead className="bg-[#f5f5f2] text-[9px] uppercase tracking-[0.09em] text-[#85888d]"><tr>{columns.map((column) => <th key={column} className="whitespace-nowrap px-3 py-3 font-medium">{column}</th>)}</tr></thead><tbody>{tableRows.map((row, rowIndex) => <tr key={rowIndex} className="border-t border-[#ecece8] text-[#4f5257]">{row.map((cell, cellIndex) => <td key={cellIndex} className="max-w-[240px] break-words px-3 py-3 align-top font-mono first:font-sans first:font-medium first:text-[#202224]">{cell || '—'}</td>)}</tr>)}</tbody></table></div>;
}

export function EmptyDetail({ text: value }: { text: string }) {
  return <div className="rounded-xl border border-dashed border-[#d8d8d3] bg-[#fafaf8] px-4 py-7 text-center"><AlertTriangle className="mx-auto h-5 w-5 text-[#a0a29f]" /><p className="mx-auto mt-2 max-w-xl text-xs leading-5 text-[#85888d]">{value}</p></div>;
}

export function QuestionCard({ title, detail }: { title: string; detail: string }) {
  return <div className="rounded-2xl border border-[#d9d9d5] bg-white p-5"><Search className="h-4 w-4 text-[#6a7771]" /><h3 className="mt-3 text-sm font-semibold text-[#242628]">{title}</h3><p className="mt-2 text-xs leading-5 text-[#777a80]">{detail}</p></div>;
}

export function SimilarityBars({ rows }: { rows: Array<[string, number]> }) {
  if (!rows.length) return <EmptyDetail text="Feature-level similarity is unavailable; aggregate distance alone is insufficient for review." />;
  return <div className="space-y-3">{rows.slice(0, 12).map(([label, value]) => <div key={label}><div className="flex justify-between gap-3 text-[10px]"><span className="truncate text-[#5f6267]">{label}</span><span className="font-mono text-[#36393c]">{percent(value)}</span></div><div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-[#ecece8]"><div className="h-full rounded-full bg-[#708b80]" style={{ width: `${Math.max(1, normalizedProbability(value) * 100)}%` }} /></div></div>)}</div>;
}

export function ProbabilityBars({ rows, empty }: { rows: Array<[string, number]>; empty: string }) {
  if (!rows.length) return <EmptyDetail text={empty} />;
  return <div className="space-y-3">{rows.map(([label, value]) => <div key={label} className="grid grid-cols-[minmax(90px,1fr)_minmax(100px,2fr)_48px] items-center gap-3 text-[10px]"><span className="truncate text-[#55585c]">{label}</span><div className="h-2 overflow-hidden rounded-full bg-[#ecece8]"><div className="h-full rounded-full bg-[#607d72]" style={{ width: `${Math.max(1, normalizedProbability(value) * 100)}%` }} /></div><span className="text-right font-mono text-[#383b3e]">{percent(value)}</span></div>)}</div>;
}

export function StagePipeline({ rows, payload }: { rows: unknown[]; payload: Json }) {
  const defaults = ['Candidate generation', 'Deduplication', 'Train-only screening', 'Purged validation', 'Calibration', 'Untouched test', 'Forward shadow', 'Decay monitoring'];
  const stages = rows.length ? rows.map(record) : defaults.map((name) => ({ name } as Json));
  return <div className="grid gap-2 md:grid-cols-4 xl:grid-cols-8">{stages.slice(0, 8).map((stage, index) => { const name = text(first(stage, ['name', 'stage'])) || defaults[index] || `stage ${index + 1}`; const count = firstNumber(stage, ['count', 'candidates', 'passed']) ?? firstNumber(payload, [`stage_counts.${index}`]); const status = text(first(stage, ['status', 'state'])) || (count == null ? 'PENDING' : 'RECORDED'); return <div key={`${name}-${index}`} className="relative rounded-xl border border-[#deded9] bg-[#fafaf8] p-3"><p className="text-[9px] font-medium uppercase tracking-[0.08em] text-[#96999d]">{index + 1}</p><p className="mt-1.5 text-[11px] font-medium leading-4 text-[#3b3e41]">{name}</p><p className="mt-3 font-mono text-sm font-semibold">{count == null ? '—' : integer(count)}</p><p className="mt-1 text-[8px] uppercase tracking-[0.08em] text-[#8b8e92]">{status}</p>{index < stages.length - 1 ? <ArrowRight className="absolute -right-3 top-1/2 z-10 hidden h-3 w-3 -translate-y-1/2 text-[#b4b6b2] xl:block" /> : null}</div>; })}</div>;
}

export function EvidenceCard({ title, icon: Icon, status, rows }: { title: string; icon: typeof Activity; status: string; rows: Array<[string, unknown]> }) {
  return <div className="rounded-2xl border border-[#d9d9d5] bg-white p-5"><div className="flex items-center justify-between gap-3"><div className="flex items-center gap-2"><Icon className="h-4 w-4 text-[#68766f]" /><h3 className="text-sm font-semibold">{title}</h3></div><StatusPill value={status} /></div><div className="mt-4 space-y-3">{rows.map(([label, value]) => <div key={label} className="flex items-start justify-between gap-4 border-t border-[#eeeeea] pt-3 text-[10px]"><span className="text-[#8b8e92]">{label}</span><span className="max-w-[60%] break-words text-right font-mono text-[#3c3f42]">{display(value)}</span></div>)}</div></div>;
}

export function HealthRow({ name, status, detail }: { name: string; status: string; detail?: string }) {
  const bad = /FAIL|ERROR|BLOCK|UNAVAILABLE|DISCONNECT|DEGRADED/i.test(status);
  return <div className="flex items-start justify-between gap-4 rounded-lg border border-[#e7e7e2] bg-[#fafaf8] p-3"><div><p className="text-xs font-medium text-[#34373a]">{name}</p>{detail ? <p className="mt-1 text-[10px] leading-4 text-[#8a8d92]">{detail}</p> : null}</div><span className={`mt-0.5 h-2 w-2 shrink-0 rounded-full ${bad ? 'bg-[#bd745f]' : 'bg-[#5d8d78]'}`} title={status} /></div>;
}

export function Checklist({ items }: { items: Array<[string, boolean]> }) {
  return <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">{items.map(([label, complete]) => <div key={label} className={`flex items-center gap-3 rounded-xl border p-3 text-xs ${complete ? 'border-[#d2dfd7] bg-[#f6faf7] text-[#315f4e]' : 'border-[#e6d8c3] bg-[#fffaf2] text-[#765b34]'}`}>{complete ? <CheckCircle2 className="h-4 w-4 shrink-0" /> : <AlertTriangle className="h-4 w-4 shrink-0" />}<span>{label}</span></div>)}</div>;
}

export function EvidenceFooter({ payload, label }: { payload: Json; label: string }) {
  const evidenceTime = first(payload, [
    'as_of',
    'generated_at',
    'updated_at',
    'decision_as_of',
    'latest_decision_as_of',
    'current_snapshot.decision_as_of',
  ]);
  return <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-[#deded9] bg-[#f2f2ef] px-4 py-3 text-[10px] text-[#74777c]"><span className="inline-flex items-center gap-2"><ShieldCheck className="h-3.5 w-3.5" />{label}</span><span className="font-mono">as_of {dateTime(evidenceTime)} · schema {text(first(payload, ['schema_version', 'version'])) || '—'} · hash {shortHash(first(payload, ['manifest_sha256', 'manifest_hash', 'data_manifest_hash', 'current_snapshot.content_sha256']))}</span></div>;
}

export function StatusPill({ value }: { value: string }) {
  const bad = /BLOCK|UNAVAILABLE|FAIL|REJECT|DEGRADED|PENDING/i.test(value);
  return <span className={`rounded-full px-2 py-1 text-[8px] font-semibold uppercase tracking-[0.08em] ${bad ? 'bg-[#fff0df] text-[#805c2d]' : 'bg-[#e6f2eb] text-[#35624f]'}`}>{value}</span>;
}

export function transitionRows(value: unknown, rowIndex: number): ReactNode[][] {
  if (Array.isArray(value)) return value.map((entry, columnIndex) => [
    `S${rowIndex + 1}`,
    `S${columnIndex + 1}`,
    percent(numberValue(entry)),
    '—',
    '—',
    'UNAVAILABLE_LEGACY_MATRIX_NO_SOFT_COUNTS',
  ]);
  const row = record(value);
  return [[
    text(first(row, ['from_state', 'from'])) || `S${rowIndex + 1}`,
    text(first(row, ['to_state', 'to'])) || '—',
    percent(firstNumber(row, ['transition_probability', 'probability', 'p'])),
    decimal(firstNumber(row, ['train_expected_transition_count']), 2),
    decimal(firstNumber(row, ['train_expected_origin_count']), 2),
    text(first(row, ['count_semantics', 'status'])) || '—',
  ]];
}
export function probabilityRows(value: unknown, labelsValue: unknown): Array<[string, number]> {
  const labels = strings(labelsValue);
  if (Array.isArray(value)) {
    if (!value.length) return [];
    const parsed = value.map(numberValue);
    if (parsed.some((item) => item == null)) return [];
    return parsed.map((item, index) => [labels[index] || `S${index + 1}`, item as number]);
  }
  const entries = Object.entries(record(value));
  if (!entries.length) return [];
  const parsed = entries.map(([key, entry]) => [key, numberValue(entry)] as const);
  if (parsed.some(([, item]) => item == null)) return [];
  return parsed.map(([key, item]) => [key, item as number]);
}

export function keyValueRows(value: unknown): Array<[string, number]> {
  return Object.entries(record(value)).flatMap(([key, entry]) => { const parsed = numberValue(entry); return parsed == null ? [] : [[key, parsed] as [string, number]]; });
}

export function rows(root: Json, paths: string[]): unknown[] {
  for (const path of paths) {
    const value = get(root, path);
    if (Array.isArray(value)) return value;
    const valueRecord = record(value);
    if (Object.keys(valueRecord).length && !('status' in valueRecord)) return Object.entries(valueRecord).map(([key, item]) => typeof item === 'object' && item && !Array.isArray(item) ? { key, ...record(item) } : { key, value: item });
  }
  return [];
}

export function firstRecord(root: Json, paths: string[]): Json {
  for (const path of paths) { const valueRecord = record(get(root, path)); if (Object.keys(valueRecord).length) return valueRecord; }
  return {};
}

export function first(root: Json | NativeResourceEnvelope | undefined, paths: string[]): unknown {
  const source = record(root);
  for (const path of paths) { const value = get(source, path); if (value !== undefined && value !== null && value !== '') return value; }
  return undefined;
}

export function firstNumber(root: Json | NativeResourceEnvelope | undefined, paths: string[]): number | undefined { return numberValue(first(root, paths)); }

function get(root: Json, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => !current || typeof current !== 'object' || Array.isArray(current) ? undefined : (current as Record<string, unknown>)[key], root);
}

export function record(value: unknown): Json { return value && typeof value === 'object' && !Array.isArray(value) ? value as Json : {}; }
export function strings(value: unknown): string[] { if (Array.isArray(value)) return value.map(text).filter(Boolean); if (typeof value === 'string') return value.split(/[|,]/).map((item) => item.trim()).filter(Boolean); const valueRecord = record(value); return Object.keys(valueRecord).filter((key) => Boolean(valueRecord[key])); }
export function resourceStatus(value: Json | NativeResourceEnvelope | undefined): string { const payload = record(value); const explicit = text(first(payload, ['status.status', 'status.evidence_status', 'status', 'health', 'state', 'evidence_status'])); return explicit ? explicit.toUpperCase() : Object.keys(payload).length ? 'AVAILABLE' : 'UNAVAILABLE'; }
export function isStrictlyAvailable(value: Json | NativeResourceEnvelope | undefined): boolean { const payload = record(value); const explicit = text(first(payload, ['status.status', 'status.evidence_status', 'status', 'health', 'state', 'evidence_status'])); return explicit.toUpperCase() === 'AVAILABLE'; }
export function isUnavailable(value: Json | NativeResourceEnvelope | undefined): boolean { const status = resourceStatus(value); return !Object.keys(record(value)).length || /BLOCK|UNAVAILABLE|EMPTY|PENDING|AWAIT|NOT_READY|MISSING/i.test(status); }
export function numberValue(value: unknown): number | undefined { const parsed = typeof value === 'number' ? value : typeof value === 'string' && value.trim() ? Number(value) : Number.NaN; return Number.isFinite(parsed) ? parsed : undefined; }
export function booleanValue(value: unknown): boolean { if (typeof value === 'boolean') return value; if (typeof value === 'number') return value !== 0; if (typeof value === 'string') return /^(true|yes|ready|available|verified|complete)$/i.test(value.trim()); return false; }
export function text(value: unknown): string { return value == null ? '' : typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean' ? String(value) : ''; }
export function integer(value?: number): string { return value == null ? '—' : Math.round(value).toLocaleString(); }
export function decimal(value?: number, digits = 2): string { return value == null ? '—' : value.toFixed(digits); }
function normalizedProbability(value: number): number { return Math.max(0, Math.min(1, value > 1 ? value / 100 : value)); }
export function percent(value?: number): string { if (value == null) return '—'; const normalized = normalizedProbability(Math.abs(value)) * Math.sign(value || 1); return `${(normalized * 100).toFixed(2)}%`; }
export function price(value: unknown): string { const parsed = numberValue(value); return parsed == null ? '—' : `$${parsed.toFixed(2)}`; }
export function rangePercent(low?: number, high?: number): string { return low == null && high == null ? '—' : `${percent(low)} → ${percent(high)}`; }
export function dateTime(value: unknown): string { const raw = text(value); if (!raw) return '—'; const date = new Date(raw); return Number.isNaN(date.valueOf()) ? raw : date.toISOString().replace('T', ' ').slice(0, 19) + 'Z'; }
export function shortDate(value: unknown): string { const raw = text(value); return raw ? raw.slice(0, 10) : '—'; }
export function shortHash(value: unknown): string { const raw = text(value); return !raw ? '—' : raw.length > 18 ? `${raw.slice(0, 10)}…${raw.slice(-6)}` : raw; }
export function yesNo(value: unknown): string { if (value == null || value === '') return '—'; if (typeof value === 'string') { if (/^(true|yes|ready|available|verified)$/i.test(value)) return 'YES'; if (/^(false|no|blocked|unavailable)$/i.test(value)) return 'NO'; return value; } return Boolean(value) ? 'YES' : 'NO'; }
export function compactPair(left: unknown, right: unknown): string { const values = [text(left), text(right)].filter(Boolean); return values.length ? values.join(' · ') : '—'; }
export function joinValues(value: unknown): string { if (Array.isArray(value)) return value.map(text).filter(Boolean).join(', ') || '—'; const valueRecord = record(value); if (Object.keys(valueRecord).length) return Object.entries(valueRecord).slice(0, 6).map(([key, item]) => `${key}:${text(item) || '…'}`).join(' · '); return text(value) || '—'; }
export function duration(value?: number, unit: 'minutes' | 'seconds' = 'minutes'): string { if (value == null) return '—'; if (unit === 'seconds') return value < 60 ? `${value.toFixed(1)}s` : `${(value / 60).toFixed(1)}m`; return value < 60 ? `${value.toFixed(1)}m` : `${(value / 60).toFixed(1)}h`; }

function display(value: unknown): ReactNode { if (value === undefined || value === null || value === '') return '—'; if (Array.isArray(value)) return value.map(text).filter(Boolean).join(', ') || '—'; if (typeof value === 'object') return joinValues(value); return String(value); }
