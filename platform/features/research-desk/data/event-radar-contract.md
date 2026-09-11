# Event radar wire contract v1

`astra-event-radar.v1` is a public, impersonal calendar and evidence artifact.
It contains no quotes, executable orders, return forecasts, or probabilities.
Calendar normalization is deterministic metadata preparation, not financial inference.

```ts
type EventRadar = {
  schemaVersion: 'astra-event-radar.v1';
  generatedAt: string; // UTC ISO; artifact generation, not source refresh
  reviewAfter: string; // earliest source review deadline, may already be past
  sources: Array<{
    id: string; title: string; url: string;
    mode: 'automatic' | 'manual_verified';
    state: 'success' | 'error';
    lastAttemptAt: string; // UTC ISO
    retrievedAt: string | null; // last successful verification, never renewed on failure
    reviewAfter: string | null;
    contentSha256: string | null;
    error: string | null; // bounded public reason, never response bodies or secrets
  }>;
  events: Array<{
    id: string; kind: 'macro' | 'earnings'; title: string;
    symbols: string[]; // [] for broad macro; not a recommendation universe
    startDate: string; endDate: string; // inclusive YYYY-MM-DD in America/New_York
    scheduledAt: string | null; // exact UTC only when source explicitly supports it
    timing: 'exact' | 'date_only';
    sourceId: string; sourceUrl: string; availableAt: string;
    referencePeriod: string | null;
    summary: string; watchFor: string; limitation: string;
    scenarios: Array<{condition: string; implication: string}>;
  }>;
  records: Array<{
    id: string; sequence: number; kind: 'hypothesis' | 'outcome';
    eventId: string; registeredAt: string; statement: string;
    sourceUrl: string | null; sourceAvailableAt: string | null;
    hypothesisId: string | null; previousSha256: string | null;
    contentSha256: string;
  }>;
  coverage: {from: string; through: string; eventCount: number; sourceCount: number; failedSourceCount: number; scope: string};
  limitations: string[];
  llmCalls: 0;
  executionEnabled: false;
  predictionEnabled: false;
};
```

All timestamps are timezone-aware UTC ISO strings. Every event's `availableAt`
is the conservative first observation time of the retained source version. It
must not be inferred from the event date or rewritten when the source fails.
`generatedAt` can advance while source times remain old. The client must display
source freshness independently and preserve last good values on failed refresh.

Event dates describe the source event precisely: an earnings **call** time must
never become an assumed **results release** time. FOMC meeting dates alone do
not establish a decision hour. A scenario is a qualitative checklist, not a
measured directional edge. Empty scenarios and records are valid.

`records` are supplied by the offline append-only journal. Hypotheses must be
registered strictly before an exact event time (or before the first local day
when no hour is verified). Outcomes reference an earlier hypothesis and a
verified primary-source URL available after the event. These records do not
establish predictive accuracy; this version exports no scoring or probabilities.
