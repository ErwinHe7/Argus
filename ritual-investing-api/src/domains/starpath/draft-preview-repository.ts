import type {
  StarpathCapabilityDecision,
  StarpathCapabilityEvaluator,
  StarpathRepository,
} from "./ports.ts";
import { StarpathError } from "./ports.ts";
import { type StarpathSnapshot, starpathSnapshotSchema } from "./schemas.ts";

const observedAt = "2026-08-30T00:00:00.000Z";
const currentUntil = "2026-11-28T23:59:59.000Z";
const manifestVersion = "draft-preview-starpath-curriculum-v1";
const manifestId = "63000000-5000-4000-8000-000000000001";

type DraftSection = Readonly<{
  kind?: "fact" | "neutral_example";
  heading: string;
  body: string;
  uncertainty: string;
}>;

type DraftSource = Readonly<{
  url: string;
  title: string;
  publisher?: string;
  claim: string;
}>;

type DraftNode = Readonly<{
  title: string;
  tarotKey: string;
  accessibleLabel: string;
  mythicMnemonic: string;
  factualSummary: string;
  sections: readonly DraftSection[];
  materialLimitations: string;
  riskContext: string;
  sources: readonly DraftSource[];
  checkPrompt: string;
  correctOption: string;
  distractor: string;
  recallPrompt: string;
  rowanExplanation: string;
}>;

const draftNodes: readonly DraftNode[] = [
  {
    title: "The Share Sigil",
    tarotKey: "the-magician",
    accessibleLabel:
      "The Magician as a memory aid for a documented unit; the card predicts nothing.",
    mythicMnemonic:
      "A sigil marks one defined unit. Here it helps distinguish an ownership unit from a promise of profit.",
    factualSummary:
      "A share of common stock represents an ownership interest in a company.",
    sections: [{
      heading: "Ownership units",
      body:
        "A company may issue shares to raise capital. Existing shares may later trade between market participants. Common-stock rights vary and can include voting or dividends, but neither a dividend nor a gain is guaranteed.",
      uncertainty:
        "Rights depend on the security class, issuer documents, corporate actions, and applicable law.",
    }],
    materialLimitations:
      "The label “stock” alone does not establish voting rights, dividend terms, seniority, liquidity, or future value.",
    riskContext:
      "A stock price can fall; in liquidation, common shareholders may receive nothing after higher-priority claims.",
    sources: [{
      url:
        "https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks",
      title: "Stocks",
      claim: "Supports ownership and common-stock characteristics.",
    }],
    checkPrompt: "Which statement describes common stock?",
    correctOption:
      "It records an ownership interest whose specific rights depend on the issue.",
    distractor: "It guarantees a dividend and a higher future price.",
    recallPrompt:
      "What does one share represent, and what does it not promise?",
    rowanExplanation:
      "A share is a documented ownership unit. Its exact rights come from the issue; the symbol on a screen does not promise income or price appreciation.",
  },
  {
    title: "The Market Lantern",
    tarotKey: "the-hermit",
    accessibleLabel:
      "The Hermit’s lantern as a memory aid for seeing one quoted field at a time; it predicts nothing.",
    mythicMnemonic:
      "A lantern illuminates separate labels: bid, ask, last trade, and order instruction are related but not interchangeable.",
    factualSummary:
      "Quotes and orders describe prices and execution instructions; a displayed or last-traded price is not an execution promise.",
    sections: [{
      heading: "Quotes and order instructions",
      body:
        "The bid is a quoted buying price and the ask is a quoted selling price; their difference is the spread. A market order generally seeks immediate execution but not a fixed execution price. A limit order sets a price boundary but may not execute. The last trade reports a completed transaction, not necessarily the next available price.",
      uncertainty:
        "Quotes cover specified quantities, prices can change, routing takes time, and order types or handling rules differ by broker and venue.",
    }],
    materialLimitations:
      "A quote or last-traded price does not show every available order, future liquidity, or the eventual price of a submitted order.",
    riskContext:
      "Fast-moving or thin markets can produce partial fills, no fill for a limit order, or a market-order price different from the displayed quote.",
    sources: [
      {
        url:
          "https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/types-orders",
        title: "Types of Orders",
        claim: "Supports common order mechanics and price boundaries.",
      },
      {
        url:
          "https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/executing-order",
        title: "Executing an Order",
        claim: "Supports execution timing, routing, and spread context.",
      },
    ],
    checkPrompt: "Which statement separates execution from price?",
    correctOption:
      "A market order may execute without guaranteeing its execution price.",
    distractor: "The last trade fixes the next execution price.",
    recallPrompt:
      "What does a limit order control, and what can it not ensure?",
    rowanExplanation:
      "An order carries instructions. Market and limit orders make different trade-offs between immediacy, price boundaries, and the possibility of no execution.",
  },
  {
    title: "The Many-Star Shield",
    tarotKey: "the-star",
    accessibleLabel:
      "The Star as a memory aid for many distinct points rather than one concentrated point; it predicts nothing.",
    mythicMnemonic:
      "A constellation needs more than one star, but a larger pattern is not an invulnerable shield.",
    factualSummary:
      "Diversification spreads exposure across investments and can reduce concentration risk, but it cannot prevent market loss.",
    sections: [{
      heading: "Spreading exposure",
      body:
        "Concentration makes one issuer, sector, or asset a larger source of total outcome. Diversification distributes exposure. A fund may hold many assets, but a narrowly focused fund or overlapping funds may still be concentrated.",
      uncertainty:
        "Correlations and holdings change. The number of positions alone does not measure how differently they behave.",
    }],
    materialLimitations:
      "Diversification cannot guarantee a gain, eliminate broad market risk, or establish that a particular allocation is suitable.",
    riskContext:
      "Multiple holdings can decline together, and fund structure, overlap, liquidity, or fees can add other risks.",
    sources: [
      {
        url:
          "https://www.investor.gov/introduction-investing/investing-basics/save-and-invest/diversify-your-investments",
        title: "Diversify Your Investments",
        claim: "Supports diversification mechanics and limitations.",
      },
      {
        url:
          "https://www.investor.gov/introduction-investing/getting-started/asset-allocation",
        title: "Asset Allocation and Diversification",
        claim: "Supports concentration and allocation context.",
      },
    ],
    checkPrompt: "What can diversification do?",
    correctOption:
      "Spread exposure and reduce some concentration risk without preventing loss.",
    distractor: "Guarantee that market declines cannot reduce value.",
    recallPrompt: "Why can a fund with many positions still be concentrated?",
    rowanExplanation:
      "Diversification describes how exposure is spread. It changes the shape of some risks; it does not erase uncertainty or loss.",
  },
  {
    title: "The Fee Eclipse",
    tarotKey: "the-moon",
    accessibleLabel:
      "The Moon as a memory aid for costs that can be less visible; it predicts nothing.",
    mythicMnemonic:
      "An eclipse can hide part of the light. Fees can reduce the value that remains, even when a quoted percentage looks small.",
    factualSummary:
      "Transaction, account, advisory, and fund operating costs reduce the value retained from an investment over time.",
    sections: [
      {
        heading: "Cost categories",
        body:
          "Costs can include commissions, account charges, asset-based advice fees, shareholder fees, and annual fund operating expenses. A fund expense ratio expresses annual operating expenses as a percentage of average net assets.",
        uncertainty:
          "Actual charges depend on agreements, product disclosures, account activity, share class, intermediaries, and costs not included in a prospectus fee table.",
      },
      {
        kind: "neutral_example",
        heading: "Recurring-cost comparison",
        body:
          "With all other inputs held constant, applying a recurring fee leaves a smaller ending value than applying no fee. This comparison illustrates arithmetic only and is not a forecast.",
        uncertainty:
          "The comparison does not model any particular product, return, tax, transaction pattern, or investor.",
      },
    ],
    materialLimitations:
      "Expense ratio does not include every possible transaction, brokerage, tax, spread, premium/discount, or advisory cost.",
    riskContext:
      "A low stated cost does not remove investment risk, and costs can apply during periods of negative performance.",
    sources: [
      {
        url:
          "https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/updated",
        title: "How Fees and Expenses Affect Your Investment Portfolio",
        claim: "Supports fee categories and the retained-value effect.",
      },
      {
        url:
          "https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/mutual-fund-and-etf-fees-and-expenses-investor-bulletin",
        title: "Mutual Fund and ETF Fees and Expenses",
        claim: "Supports fund fee labels and expense-ratio scope.",
      },
    ],
    checkPrompt: "What does an expense ratio describe?",
    correctOption:
      "Annual fund operating expenses as a percentage of average net assets.",
    distractor: "Every cost that any holder can incur.",
    recallPrompt:
      "Why can a recurring fee affect more than the amount deducted in its first year?",
    rowanExplanation:
      "A fee is a cost with a defined basis and frequency. Reading its label, rate, exclusions, and source reveals what the number covers and what it leaves out.",
  },
  {
    title: "The Filing Grimoire",
    tarotKey: "the-high-priestess",
    accessibleLabel:
      "The High Priestess as a memory aid for opening a structured public record; it predicts nothing.",
    mythicMnemonic:
      "A grimoire has named chapters. A Form 10-K also has defined sections whose labels tell the reader what type of disclosure follows.",
    factualSummary:
      "A Form 10-K describes a public company’s business, significant risks, and audited financial statements.",
    sections: [{
      heading: "A structured filing",
      body:
        "Item 1 describes the business. Item 1A presents significant risk factors. Item 7 contains management’s discussion and analysis. Item 8 contains audited financial statements, including income statements, balance sheets, cash-flow statements, stockholders’ equity, and notes. Public filings are available through EDGAR.",
      uncertainty:
        "The company prepares the filing, estimates and judgments affect reported amounts, risks can change after the reporting period, and SEC filing or review is not an endorsement of an issuer.",
    }],
    materialLimitations:
      "One line item or one reporting period does not explain a company by itself. Notes, accounting policies, dates, amendments, and later filings provide context.",
    riskContext:
      "Filings may contain forward-looking statements and identified risks; historical statements do not establish future outcomes.",
    sources: [
      {
        url:
          "https://www.investor.gov/introduction-investing/getting-started/researching-investments/how-read-10-k",
        title: "How to Read a 10-K",
        claim: "Supports the filing’s section structure and purpose.",
      },
      {
        url:
          "https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/how-read",
        title: "How to Read a 10-K/10-Q",
        claim: "Supports financial-statement and SEC-role context.",
      },
    ],
    checkPrompt:
      "Where are audited income, balance-sheet, and cash-flow statements found in a 10-K?",
    correctOption: "Financial Statements and Supplementary Data.",
    distractor: "The stock-price quote.",
    recallPrompt:
      "What different questions do Business, Risk Factors, and Financial Statements answer?",
    rowanExplanation:
      "The filing is a dated, structured disclosure. Its headings help separate the company’s business description, risks, management discussion, and audited numbers.",
  },
  {
    title: "The Fund and Bond Map",
    tarotKey: "the-chariot",
    accessibleLabel:
      "The Chariot as a memory aid for reading two labeled routes—fund ownership and issuer debt; it predicts nothing.",
    mythicMnemonic:
      "A map separates routes before comparing their labels. An ETF share and a bond describe different legal and economic structures.",
    factualSummary:
      "Fund documents describe a fund portfolio, objective, risks, and expenses; bond terms describe a debt claim and its payment schedule.",
    sections: [
      {
        heading: "Fund structure",
        body:
          "A registered ETF pools assets; each share represents an interest in its portfolio. Its prospectus describes objectives, strategies, risks, and a standardized fee table, while holdings and shareholder reports add dated detail.",
        uncertainty:
          "Fund holdings, index methods, premiums or discounts, and liquidity change over time.",
      },
      {
        heading: "Bond terms and risks",
        body:
          "A bond is debt issued by a government, municipality, or corporation. Terms can include face value, coupon, maturity, and yield. Risks can include issuer credit/default, interest-rate, inflation, and liquidity risk. A bond sold before maturity may trade above or below face value.",
        uncertainty:
          "Yields, credit conditions, market rates, and liquidity change over time.",
      },
    ],
    materialLimitations:
      "A product label does not establish diversification, cost, tax treatment, credit quality, liquidity, or future return. Registered ETFs are not the same as every exchange-traded product.",
    riskContext:
      "ETF holdings can lose value. Bond issuers can default, and changing rates or liquidity can change a bond’s market price.",
    sources: [
      {
        url:
          "https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-2",
        title: "Exchange-Traded Funds",
        claim: "Supports registered ETF structure, documents, and risks.",
      },
      {
        url:
          "https://www.investor.gov/introduction-investing/investing-basics/investment-products/bonds-or-fixed-income-products/bonds",
        title: "Bonds",
        claim: "Supports bond terms, pricing context, and risks.",
      },
    ],
    checkPrompt: "Which pair names a bond term and a bond risk?",
    correctOption: "Maturity and issuer credit risk.",
    distractor: "Expense ratio and guaranteed gain.",
    recallPrompt:
      "Which documents or fields describe what a fund holds and what a bond promises to pay?",
    rowanExplanation:
      "Start with structure: a fund share points to a portfolio; a bond points to an issuer’s debt obligation. Then read each document’s dated terms, costs, and risks.",
  },
  {
    title: "The False Sun",
    tarotKey: "the-sun",
    accessibleLabel:
      "The Sun as a memory aid for checking whether a bright claim is supported; it predicts nothing.",
    mythicMnemonic:
      "A painted sun can look bright without producing light. A vivid pitch can create emotion without providing verifiable evidence.",
    factualSummary:
      "Promises of high or guaranteed returns with little risk, urgency, false credentials, and unsolicited pitches are recognized fraud warning signs.",
    sections: [{
      heading: "Fraud warning signs",
      body:
        "Official investor-protection material identifies warning signs including unlicensed people, exaggerated credentials, “risk-free” or guaranteed-return claims, social-pressure pitches, urgency, fake testimonials, unsolicited contact, and unusual payment requests.",
      uncertainty:
        "A warning sign is not by itself a legal finding. Fraud determinations depend on evidence and the relevant authority.",
    }],
    materialLimitations:
      "Familiarity, professional-looking media, group membership, popularity, or a confident tone do not independently verify a claim.",
    riskContext:
      "Fraud can cause financial loss, identity theft, unauthorized transfers, or loss of access to funds; recovering transferred assets may be difficult.",
    sources: [
      {
        url:
          "https://www.investor.gov/protect-your-investments/fraud/how-avoid-fraud/red-flags-investment-fraud-checklist",
        title: "Red Flags of Investment Fraud Checklist",
        claim: "Supports recognized presentation and promise warning signs.",
      },
      {
        url:
          "https://www.investor.gov/protect-your-investments/fraud/protect-your-money",
        title: "Protect Your Money: How to Avoid Investment Scams",
        claim: "Supports verification steps and scam-risk context.",
      },
    ],
    checkPrompt: "Which statement is a recognized warning sign?",
    correctOption:
      "A pitch combines high guaranteed returns, little risk, and pressure to act immediately.",
    distractor: "A dated public filing lists material risks.",
    recallPrompt:
      "Name two warning signs that concern how a pitch is presented rather than what security it names.",
    rowanExplanation:
      "Warning signs prompt verification; they are not predictions. Separate the emotional pressure from the claim, then look for independent records and dates.",
  },
  {
    title: "The Verification Compass",
    tarotKey: "justice",
    accessibleLabel:
      "Justice as a memory aid for matching a claim to an independent record; it predicts nothing.",
    mythicMnemonic:
      "A compass checks direction against a reference point. Verification checks a claim against a dated official record rather than intuition or popularity.",
    factualSummary:
      "Official filing, registration, disciplinary, source-date, conflict, and reporting records can be checked independently.",
    sections: [{
      heading: "Independent records",
      body:
        "EDGAR provides company filings. IAPD provides adviser registration, business, fee, conflict, and disciplinary information; BrokerCheck provides broker and firm background and disciplinary information. Source title, publisher, observation date, and effective period help identify which claim a record supports. The SEC provides a reporting channel for suspected securities-law violations.",
      uncertainty:
        "Registration does not guarantee honesty, competence, performance, or the merits of a security. Records can be amended, differently scoped, or incomplete for a particular question.",
    }],
    materialLimitations:
      "One database does not cover every person, product, jurisdiction, conflict, or allegation. A search result is not a recommendation or a legal conclusion.",
    riskContext:
      "Imposters can misuse real names or registration details, and stale screenshots can omit later changes or discipline.",
    sources: [
      {
        url:
          "https://www.investor.gov/introduction-investing/getting-started/researching-investments/ask-and-check",
        title: "Ask and Check",
        claim: "Supports IAPD and BrokerCheck verification fields.",
      },
      {
        url:
          "https://www.sec.gov/submit-tip-or-complaint/report-possible-securities-law-violations",
        title: "Report Possible Securities Law Violations",
        publisher: "U.S. Securities and Exchange Commission",
        claim: "Supports the SEC reporting path.",
      },
    ],
    checkPrompt: "What can BrokerCheck or IAPD establish?",
    correctOption:
      "Registration and disclosed background or disciplinary information within the tool’s scope.",
    distractor: "That a promoted investment will gain value.",
    recallPrompt:
      "Which four metadata fields help bind a factual claim to a source?",
    rowanExplanation:
      "Verification means matching a specific claim to the appropriate current record, noting the record’s scope and date, and keeping the result separate from any investment decision.",
  },
] as const;

function uuid(group: string, ordinal: number): string {
  return `63000000-${group}-4000-8000-${ordinal.toString().padStart(12, "0")}`;
}

function nodeSnapshot(node: DraftNode, index: number) {
  const ordinal = index + 1;
  const lessonId = uuid("0000", ordinal);
  const revisionId = uuid("1000", ordinal);
  const questionId = uuid("2000", ordinal);
  return {
    node_ordinal: ordinal,
    pathway_ordinal: Math.floor(index / 2) + 1,
    pathway_position: (index % 2) + 1,
    state: ordinal === 1 ? "current" as const : "locked" as const,
    lesson_id: lessonId,
    revision_id: revisionId,
    title: node.title,
    guide: {
      tarot_key: node.tarotKey,
      accessible_label: node.accessibleLabel,
    },
    mythic_mnemonic: node.mythicMnemonic,
    factual_summary: node.factualSummary,
    factual_sections: node.sections.map((section, sectionIndex) => ({
      ordinal: sectionIndex + 1,
      kind: section.kind ?? "fact" as const,
      heading: section.heading,
      body: section.body,
      uncertainty: section.uncertainty,
      observed_at: observedAt,
      evidence: node.sources.map((source, sourceIndex) => ({
        ordinal: sourceIndex + 1,
        canonical_url: source.url,
        source_title: source.title,
        publisher: source.publisher ??
          "U.S. Securities and Exchange Commission",
        source_observed_at: observedAt,
        effective_at: null,
        retrieved_at: observedAt,
        current_until: currentUntil,
        claim_summary: source.claim,
      })),
    })),
    material_limitations: node.materialLimitations,
    risk_context: node.riskContext,
    recall_prompt: node.recallPrompt,
    rowan_explanation: node.rowanExplanation,
    knowledge_check: {
      id: questionId,
      prompt: node.checkPrompt,
      options: [
        { id: uuid("3000", ordinal), ordinal: 1, label: node.correctOption },
        { id: uuid("4000", ordinal), ordinal: 2, label: node.distractor },
      ],
    },
  };
}

const snapshot: StarpathSnapshot = starpathSnapshotSchema.parse({
  availability: "available",
  version: 1,
  authority: {
    capability_version: 1,
    manifest_id: manifestId,
    manifest_version: manifestVersion,
    policy_version: "starpath-no-advice-v1-draft",
    environment: "beta",
    jurisdiction: "US",
  },
  session: null,
  theme: {
    id: "63000000-6000-4000-8000-000000000001",
    key: "constellation-map",
    title: "Walk the draft constellation",
    horoscope_frame:
      "Walk a constellation one sourced concept at a time. This is a memory frame, not a horoscope or forecast.",
    factual_focus: "Terms, risk, documents, and verification.",
    accessible_label:
      "A downward constellation path connecting eight draft educational lessons.",
  },
  progress: null,
  nodes: draftNodes.map(nodeSnapshot),
  recall: null,
  command_effect: null,
  answer: null,
});

export function createDraftPreviewStarpathRepository(): StarpathRepository {
  const rejectMutation = async (): Promise<never> => {
    throw new StarpathError("starpath_unavailable");
  };
  return Object.freeze({
    read: async () => snapshot,
    startOrResume: rejectMutation,
    answer: rejectMutation,
    skipRecall: rejectMutation,
  });
}

export function createBetaDraftStarpathCapabilityEvaluator(
  now: () => Date = () => new Date(),
): StarpathCapabilityEvaluator {
  return Object.freeze({
    evaluate: async (): Promise<StarpathCapabilityDecision> => {
      const evaluatedAt = now();
      return {
        branch: "starpath",
        available: true,
        environment: "beta",
        jurisdiction: "US",
        capabilityVersion: 1,
        evaluatedAt: evaluatedAt.toISOString(),
        expiresAt: new Date(evaluatedAt.getTime() + 5 * 60 * 1_000)
          .toISOString(),
        protectedRoutes: [
          "starpath.read",
          "starpath.start",
          "starpath.answer",
          "starpath.recall.skip",
        ],
      };
    },
  });
}

export const draftPreviewStarpathManifestVersion = manifestVersion;
