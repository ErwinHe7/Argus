import { detectEventIntent, formatEventsForAgentContext, searchEvents } from './events/search';
import { listListings } from './store';

const EVENT_KW = ['party', 'event', 'concert', 'show', 'gallery', 'tonight', 'weekend', 'ticket'];
const FURNITURE_KW = ['furniture', 'desk', 'chair', 'couch', 'sofa', 'ikea', 'selling', 'sell'];

export type FanoutContextBundle = {
  feedContext: string;
  tradeContext: string | null;
  eventContext: string | null;
  userContent: string;
};

export async function buildFanoutListingContext(content: string): Promise<string | null> {
  const lower = content.toLowerCase();
  const isEvent = EVENT_KW.some((keyword) => lower.includes(keyword));
  const isFurniture = FURNITURE_KW.some((keyword) => lower.includes(keyword));
  if (!isEvent && !isFurniture) return null;

  const category = isFurniture ? 'furniture' : 'tickets';
  try {
    const all = await listListings({ category });
    const top5 = all.filter((listing) => listing.status === 'open').slice(0, 5);
    if (top5.length === 0) return null;
    const lines = top5.map((listing) => {
      const price = listing.asking_price_cents > 0
        ? `$${(listing.asking_price_cents / 100).toFixed(0)}`
        : 'price TBD';
      const location = listing.location ? ` - ${listing.location}` : '';
      return `- "${listing.title}" - ${price}${location} (see /trade/${listing.id})`;
    });
    return `[Live listings on AXIO7 Trade]\n${lines.join('\n')}`;
  } catch {
    return null;
  }
}

export async function buildFanoutEventContext(content: string): Promise<string | null> {
  if (!detectEventIntent(content)) return null;
  return await searchEvents(content, { limit: 4 })
    .then(formatEventsForAgentContext)
    .then((context) => context || null)
    .catch(() => null);
}

export async function buildFanoutContext(content: string): Promise<FanoutContextBundle> {
  const [tradeContext, eventContext] = await Promise.all([
    buildFanoutListingContext(content),
    buildFanoutEventContext(content),
  ]);
  const userContent = [content, tradeContext ?? '', eventContext ?? ''].filter(Boolean).join('\n\n');
  return {
    feedContext: content,
    tradeContext,
    eventContext,
    userContent,
  };
}
