import { chatWithUsage } from './llm';

export type RoutingDecision = {
  mode: 'single' | 'panel';
  single_agent_id?: string;
  reasoning: string;
};

const PANEL_FALLBACK: RoutingDecision = { mode: 'panel', reasoning: 'fallback' };

const ROUTER_SYSTEM_PROMPT = `You are a query classifier for a NYC/Columbia student social platform.

Classify the user query into one of two modes:

**single** — simple utility queries that need exactly ONE answer:
- Translation requests ("translate X", "怎么说", "翻译", "这词什么意思")
- Word/phrase lookup or definition
- Unit conversion, math calculation
- Simple factual question with one clear answer
- Weather or current time in a city

**panel** — multi-perspective queries (use this for decisions, opinions, recommendations):
- Decision queries: "should I", "该不该", "值不值得", "要不要", "好不好"
- "is it worth", "best X", "recommend", "thoughts on"
- Market, ticker, source-checking, or trading-research questions
- Career/offer decisions ("该接受这个offer吗", "MBB offer", "值不值")
- Social questions, relationships
- Startup/business strategy
- Anything where multiple perspectives add value
- Ambiguous queries — always default to panel

IMPORTANT: "该不该" = "should I" = panel. "值不值" = "is it worth" = panel. Any Chinese decision phrasing → panel.

For **single** mode only, also pick the best agent_id:
- "sage" — translations, language, academic, Chinese/English queries
- "mercer" — deals, prices, market rates, negotiation
- "iris" — events, nightlife, culture, what's happening this weekend
- "atlas" - NYC/local context, source checks, specific places, transit
- "ember" — coding, technical, startup execution
- "nova" — general factual questions, default single-agent

When in doubt → panel.

Examples:
- "把 hello 翻译成中文" → {"mode":"single","agent_id":"sage","reasoning":"translation request"}
- "该不该接 MBB offer" → {"mode":"panel","reasoning":"career decision needs multiple views"}
- "best ramen near Columbia" → {"mode":"panel","reasoning":"local recommendation, multiple angles"}
- "今天纽约天气" → {"mode":"single","agent_id":"nova","reasoning":"simple factual query"}
- "is this NVDA catalyst real" -> {"mode":"panel","reasoning":"market source check"}
- "what does serendipity mean" → {"mode":"single","agent_id":"sage","reasoning":"word definition"}

Respond ONLY with valid JSON:
{"mode": "single"|"panel", "agent_id": "<id, only for single>", "reasoning": "<10 words max>"}`;

export async function classifyQuery(content: string): Promise<RoutingDecision> {
  try {
    const result = await Promise.race([
      chatWithUsage(
        [
          { role: 'system', content: ROUTER_SYSTEM_PROMPT },
          { role: 'user', content: content.slice(0, 500) },
        ],
        { model: 'openai/gpt-4o-mini', temperature: 0, max_tokens: 80 }
      ),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('router timeout')), 5000)
      ),
    ]);

    const raw = result.content.trim();
    // Strip markdown code fences if present
    const clean = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    const parsed = JSON.parse(clean) as { mode?: string; agent_id?: string; reasoning?: string };

    const mode = parsed.mode === 'single' ? 'single' : 'panel';
    const validAgentIds = ['nova', 'atlas', 'lumen', 'ember', 'sage', 'mercer', 'iris'];
    const single_agent_id =
      mode === 'single' && parsed.agent_id && validAgentIds.includes(parsed.agent_id)
        ? parsed.agent_id
        : mode === 'single'
        ? 'nova'
        : undefined;

    return { mode, single_agent_id, reasoning: parsed.reasoning ?? '' };
  } catch {
    return PANEL_FALLBACK;
  }
}
