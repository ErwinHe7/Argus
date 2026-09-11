import type { EventRadar } from './contract';
import { eventOrder, eventTime, eventUpcoming, sourceCurrent, type RadarEvent } from './useRadar';

export type Explanation = { title: string; paragraphs: string[]; links: { label: string; href: string }[] };
export function explainEvidence(question: string, data: EventRadar, event: RadarEvent | undefined, now: number): Explanation {
  const q = question.toLowerCase().trim();
  const found = data.events.find(item => item.symbols.some(symbol => q.split(/[\s,;?!$]+/).includes(symbol.toLowerCase())))
    ?? data.events.find(item => /micron/.test(q) && /micron/i.test(item.title))
    ?? data.events.find(item => /adobe/.test(q) && /adobe/i.test(item.title))
    ?? data.events.find(item => /cpi|inflation|通胀/.test(q) && /consumer price|cpi/i.test(item.title))
    ?? data.events.find(item => /fomc|fed|利率|美联储/.test(q) && /fomc/i.test(item.title));
  const selected = found ?? event;
  if (/buy|purchase|sell|买|卖|推荐/.test(q)) return { title: 'Start with the screen, then check the catalyst.', paragraphs: [
    'Picks ranks the tracked stocks by three published technical checks. Its source date is shown beside the ranking; an old screen is not a current buy signal.',
    selected ? `${selected.title} is a catalyst to review (${eventTime(selected)}). ${selected.watchFor}` : 'Choose an event to see what is known and what would change the view.',
    'This radar does not know your holdings or risk limits. It has no validated directional forecast or order permission.'
  ], links: [{ label: 'Review the stock shortlist', href: '#/home' }, ...(selected ? [{ label: 'Read the event source', href: selected.sourceUrl }] : [])] };
  if (/predict|probabil|win|accuracy|forecast|预测|胜率|收益/.test(q)) return { title: 'The forecast record is still unvalidated.', paragraphs: [
    `The public evidence contains ${data.records.filter(record => record.kind === 'hypothesis').length} registered hypotheses and ${data.records.filter(record => record.kind === 'outcome').length} outcome records. Calendar dates do not predict a market move.`,
    'A directional call needs a time-stamped model release, an outcome definition, and an untouched evaluation sample. No probability or win rate is published for this release.',
    'Earnings research compares a pre-event option premium with observed historical moves. Neither quantity alone establishes a profitable trade.'
  ], links: [{ label: 'Inspect the research record', href: '#/forecast' }] };
  if (/automatic|trade for|execute|vps|token|自动|服务器/.test(q)) return { title: 'Calendar monitoring runs without AI calls.', paragraphs: [
    'The hosted calendar service checks official sources on its schedule. This explanation is assembled from the published records and makes no paid model call.',
    'Strategy research and the paper connector are separate tools. The connector requires an authenticated broker session on an always-on computer; a VPS is one way to provide that.',
    'This assistant cannot place orders, change strategy rules, or activate real-money trading.'
  ], links: [{ label: 'Open strategies and paper setup', href: '#/strategies' }] };
  if (/next|upcoming|week|coming|接下来|本周/.test(q) && !found) {
    const next = data.events.filter(item => eventUpcoming(item, now)).sort((a,b) => eventOrder(a).localeCompare(eventOrder(b))).slice(0, 3);
    return { title: 'The next recorded catalysts', paragraphs: next.length ? next.map(item => `${item.title}: ${eventTime(item)}. ${sourceCurrent(data, item, now) ? 'Source is within its review window.' : 'Check the retained date with the source.'}`) : ['No upcoming events are present in the current coverage. That does not mean the market calendar is empty.'], links: next.map(item => ({ label: item.title, href: item.sourceUrl })) };
  }
  if (!selected) return { title: 'Choose a catalyst first.', paragraphs: ['I can explain the recorded date, source, watch conditions, missing evidence, or how paper trading works. I cannot answer an unrelated question from these records.'], links: [] };
  const supported = /why|watch|risk|source|date|when|explain|evidence|missing|cpi|fomc|fed|inflation|micron|利率|为什么|风险|何时|解释|来源|通胀/.test(q) || !!found;
  if (!supported) return { title: 'That answer is not in this evidence.', paragraphs: ['Ask what to watch, when the event is scheduled, which source supports it, or what is missing. This version uses a small set of evidence queries; it is not a general chat model.'], links: [] };
  return { title: selected.title, paragraphs: [
    `${eventTime(selected)}. ${selected.summary}`, `Watch: ${selected.watchFor}`, `Limit: ${selected.limitation}`,
    sourceCurrent(data, selected, now) ? 'The source is within its review window. A scheduled event is not a prediction of its outcome.' : 'The source needs review. The previous date is preserved, but has not been freshly verified.'
  ], links: [{ label: 'Primary source', href: selected.sourceUrl }] };
}
