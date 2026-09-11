import 'server-only';

import { ivLabEventsSchema, validateIvLabBundle, type IvLabBundle, type IvLabEvents,
  type IvLabOverview, type IvLabSymbol, type IvLabTicker } from './types';

// Keep large offline artifacts out of TypeScript's inferred JSON type graph.
// Literal require paths also retain the files in the Next server bundle.
const rawBundle: unknown = require('./artifacts/iv-lab.json');
const rawEvents: unknown = require('./artifacts/events.json');
let checked = false;
let retained: { bundle: IvLabBundle; events: IvLabEvents } | null = null;

function loadSnapshot() {
  if (checked) return retained;
  checked = true;
  const bundle = validateIvLabBundle(rawBundle);
  const events = ivLabEventsSchema.safeParse(rawEvents);
  if (bundle && events.success) retained = { bundle, events: events.data };
  return retained;
}

/** Historical evidence retains its original dates and historical freshness label. */
export function getIvLabOverview(): IvLabOverview | null {
  const data = loadSnapshot();
  if (!data) return null;
  const { symbols, ...metadata } = data.bundle;
  return {
    ...metadata,
    symbols: symbols.map(({ configurations: _configurations, ...symbol }) => symbol),
    events: data.events,
  };
}

export function getIvLabSymbol(symbol: IvLabTicker): IvLabSymbol | null {
  return loadSnapshot()?.bundle.symbols.find((item) => item.symbol === symbol) ?? null;
}
