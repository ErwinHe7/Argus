/** Plain-language descriptions. Executable rules and calculations live in Rust. */
export const STRATEGIES = [
  {
    id: 'MR-v1' as const, title: 'Mean reversion', premise: 'Look for a rebound after an unusually weak close.',
    entry: 'At least 2 standard deviations below the 20-session mean, with RSI 14 at or below 30.',
    exit: 'Return to the 20-session mean, 10 held sessions, or the local stop.',
    stop: '2 × signal-day ATR below the first fill.',
    failure: 'A persistent decline can trigger repeated losing entries. A lower price alone does not establish a bottom.',
    character: 'Best hypothesis to test in a stable range.',
  },
  {
    id: 'MOM-v1' as const, title: 'Momentum', premise: 'Follow a price breakout while the longer trend is rising.',
    entry: 'Close above the preceding 55-session high and the 200-session moving average.',
    exit: 'Close below the preceding 20-session low, or the rising local stop.',
    stop: 'Initially 3 × signal-day ATR below the first fill; the trailing stop can only rise.',
    failure: 'Sideways markets can produce a string of false breakouts. Price gaps can exceed the planned stop loss.',
    character: 'Best hypothesis to test in a sustained upward trend.',
  },
];
export type StrategyId = typeof STRATEGIES[number]['id'];
export const STEPS = ['Choose strategy', 'Configure rules', 'Review evidence', 'Connect computer', 'Start paper trading'] as const;

export function validSymbol(value: string): boolean { return /^[A-Z][A-Z0-9.\-]{0,9}$/.test(value); }
export function displayTime(value: string | null | undefined): string {
  if (!value || !Number.isFinite(Date.parse(value))) return 'Not reported';
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', second: '2-digit', timeZone: 'America/New_York' }).format(new Date(value)) + ' ET';
}
export function elapsedLabel(value: string | null | undefined, now: number): string {
  if (!value || !Number.isFinite(Date.parse(value))) return 'No heartbeat';
  const seconds = Math.max(0, Math.floor((now - Date.parse(value)) / 1000));
  return seconds < 60 ? `${seconds}s ago` : `${Math.floor(seconds / 60)}m ago`;
}
