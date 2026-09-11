export type IvEvidence = {
  title: string; relationship: string; mechanism: string; limitation: string;
  sources: { label: string; url: string }[];
};

/** Editorial context. Market observations live in the dated research artifact. */
export const IV_EVIDENCE: Record<string, IvEvidence> = {
  DXYZ: {
    title: 'Portfolio value and the premium to NAV', relationship: 'Investment fund',
    mechanism: 'Part of the fund’s portfolio provides exposure to Anthropic’s valuation. Consider both net asset value and the fund’s market price.',
    limitation: 'A change in Anthropic’s valuation does not translate into the same percentage gain in DXYZ. Other holdings and the premium or discount to NAV also affect its price.',
    sources: [{ label: 'Destiny official portfolio', url: 'https://destiny.xyz/tech100' }],
  },
  ZM: {
    title: 'Equity investment and the core business', relationship: 'Equity investor',
    mechanism: 'Track changes in the carrying value of the Anthropic investment alongside Zoom’s own business performance and valuation.',
    limitation: 'Recognized fair-value adjustments may already be reflected in the accounts and share price. The entire holding’s value is not incremental profit.',
    sources: [{ label: 'Zoom investor relations', url: 'https://investors.zoom.us/financials/sec-filings' }],
  },
  AVGO: {
    title: 'From model demand to compute orders', relationship: 'TPU compute partner',
    mechanism: 'Track whether Anthropic’s compute partnership with Google and Broadcom translates into confirmed demand and measurable financial effects.',
    limitation: 'The partnership establishes a business connection. It does not, on its own, determine revenue timing, stock direction or IV changes.',
    sources: [{ label: 'Anthropic partnership announcement', url: 'https://www.anthropic.com/news/google-broadcom-partnership-compute' }],
  },
  AMZN: {
    title: 'Investment and cloud infrastructure', relationship: 'Investor · AWS',
    mechanism: 'Anthropic’s growth may affect the investment’s value, AWS services, Trainium and Bedrock through different channels.',
    limitation: 'Amazon has a broad business. News about one partner cannot establish the magnitude of a move in the company’s share price.',
    sources: [{ label: 'Anthropic and Amazon announcement', url: 'https://www.anthropic.com/news/anthropic-amazon-compute' }],
  },
  GOOGL: {
    title: 'Cooperation and competition', relationship: 'Investor · Cloud and TPU',
    mechanism: 'Compute and investment ties coexist with competition from Gemini. Specific product developments may affect valuation through different channels.',
    limitation: 'Anthropic’s product progress alone does not establish Google’s share-price direction. This page uses GOOGL data.',
    sources: [{ label: 'Official compute partnership announcement', url: 'https://www.anthropic.com/news/google-broadcom-partnership-compute' }],
  },
  NVDA: {
    title: 'GPU demand and investment commitments', relationship: 'GPU partner · Investment commitment',
    mechanism: 'Track actual progress in GPU deployment, compute demand and announced investment commitments.',
    limitation: 'An investment commitment is not proof that the full amount has been funded. GPU demand also depends on other customers, supply and competition.',
    sources: [{ label: 'Anthropic strategic partnership announcement', url: 'https://www.anthropic.com/news/microsoft-nvidia-anthropic-announce-strategic-partnerships' }],
  },
};

export const SYMBOL_NAMES: Record<string, string> = {
  DXYZ: 'Destiny Tech100', ZM: 'Zoom', AVGO: 'Broadcom', AMZN: 'Amazon', GOOGL: 'Alphabet', NVDA: 'NVIDIA',
};
