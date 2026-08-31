import type { ComplianceAssessment } from './types';

const BLOCKED_PATTERNS = [
  /\binsider\b/i,
  /\binside\s+information\b/i,
  /\bmaterial\s+non[-\s]?public\b/i,
  /\bmnpi\b/i,
  /\bconfidential\b/i,
  /\bleak(?:ed|s)?\b/i,
  /\bprivate\s+(?:dm|message|server|channel|group)\b/i,
  /\bbypass\b/i,
  /\bhack(?:ing)?\b/i,
  /\bcredential\b/i,
  /\bpaywall\b/i,
  /\bcaptcha\b/i,
  /内幕/,
  /非公开/,
  /机密/,
  /破解/,
  /绕过/,
  /黑进/,
];

const ADVICE_PATTERNS = [
  /\bshould\s+i\s+(?:buy|sell|short|long)\b/i,
  /\btell\s+me\s+what\s+to\s+(?:buy|sell|short)\b/i,
  /\bposition\s+sizing\b/i,
  /\bstop\s+loss\b/i,
  /\bguarantee(?:d)?\b/i,
  /\bauto(?:mated)?\s+trad(?:e|ing)\b/i,
  /我该买/,
  /我该卖/,
  /仓位/,
  /止损/,
  /稳赚/,
  /保证收益/,
];

export const MARKET_DISCLAIMER =
  'AXIO7 Market Intelligence provides general market research from public or authorized sources only. It is not investment, legal, tax, or trading advice; it does not execute trades, personalize portfolio recommendations, or use material non-public information.';

export function assessMarketRequest(text: string): ComplianceAssessment {
  const reasons: string[] = [];
  const guardrails = [
    'Use only public, official, licensed, or user-authorized data sources.',
    'Do not request, solicit, store, trade on, or summarize material non-public information.',
    'Do not generate personalized buy/sell instructions, position sizing, or automated order execution.',
    'Keep outputs framed as event research, evidence quality, and decision support.',
  ];

  if (BLOCKED_PATTERNS.some((pattern) => pattern.test(text))) {
    reasons.push('The request appears to ask for insider, confidential, private, or unauthorized information.');
  }

  const adviceRisk = ADVICE_PATTERNS.some((pattern) => pattern.test(text));
  if (adviceRisk) {
    reasons.push('The request may be interpreted as personalized trading advice or automated trading guidance.');
  }

  if (reasons.some((reason) => reason.includes('insider') || reason.includes('confidential') || reason.includes('unauthorized'))) {
    return {
      allowed: false,
      severity: 'blocked',
      reasons,
      guardrails,
    };
  }

  return {
    allowed: true,
    severity: adviceRisk ? 'caution' : 'clear',
    reasons: adviceRisk ? reasons : ['Request is within market research and public-source intelligence boundaries.'],
    guardrails,
  };
}
