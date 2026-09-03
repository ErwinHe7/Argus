import type {
  StarpathCapabilityDecision,
  StarpathCapabilityEvaluator,
  StarpathRepository,
} from "./ports.ts";
import { StarpathError } from "./ports.ts";
import { type StarpathSnapshot, starpathSnapshotSchema } from "./schemas.ts";

const observedAt = "2026-08-31T00:00:00.000Z";
const currentUntil = "2026-11-29T23:59:59.000Z";
const manifestVersion = "draft-preview-starpath-curriculum-v2";
const manifestId = "63000000-5000-4000-8000-000000000001";

type DraftSource = Readonly<{
  url: string;
  title: string;
  publisher: string;
  claim: string;
}>;

type DraftSection = Readonly<{
  kind?: "fact" | "neutral_example";
  heading: string;
  body: string;
  uncertainty: string;
  sources: readonly DraftSource[];
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
  checkPrompt: string;
  correctOption: string;
  distractor: string;
  recallPrompt: string;
  rowanExplanation: string;
}>;

const draftNodes: readonly DraftNode[] = [
  {
    title: "Start Here",
    tarotKey: "the-magician",
    accessibleLabel:
      "The Magician as an optional memory aid for naming an instrument and its risks; the card predicts nothing.",
    mythicMnemonic:
      "The Magician names each tool before using it. Name what you own, how it can change, and what could go wrong.",
    factualSummary:
      "Understand what a stock is, how gains and losses happen, and the three questions to ask before acting.",
    sections: [
      {
        heading: "What Is a Stock?",
        body:
          "A share of common stock represents an ownership interest in a company. The exact voting, dividend, and other rights depend on the security class and issuer documents.",
        uncertainty:
          "Do not assume every share has identical rights. Check the security class and current company filings.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks",
          title: "Stocks - FAQs",
          publisher: "Investor.gov",
          claim:
            "Supports the ownership definition and the fact that stockholder rights and returns are not guaranteed.",
        }],
      },
      {
        heading: "How Do You Make—or Lose—Money?",
        body:
          "A stockholder may gain if the market price rises or if the company pays dividends. A lower sale price, fees, or a company failure can instead create a loss.",
        uncertainty:
          "Price gains and dividends are never guaranteed, and costs or taxes can change the amount kept.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks",
          title: "Stocks - FAQs",
          publisher: "Investor.gov",
          claim:
            "Supports common ways stockholders may gain or lose money and the absence of guaranteed returns.",
        }],
      },
      {
        heading: "Three Rules Before You Buy Anything",
        body:
          "Be able to name what you are buying, why it might gain or lose value, and how much loss the decision could create. Research first; speed is not evidence.",
        uncertainty:
          "A checklist improves discipline but cannot turn an uncertain investment into a guaranteed outcome.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/getting-started/investing-your-own/online-investing",
          title: "Online Investing",
          publisher: "Investor.gov",
          claim:
            "Supports researching an investment and understanding risks before acting online.",
        }],
      },
    ],
    materialLimitations:
      "A stock label does not establish voting rights, dividends, liquidity, tax treatment, or future value.",
    riskContext:
      "Stock prices can fall, dividends can change, and common shareholders may receive nothing after higher-priority claims in liquidation.",
    checkPrompt: "Which statement is accurate about common stock?",
    correctOption:
      "It represents an ownership interest, while gains and dividends are not guaranteed.",
    distractor: "It guarantees income and a higher future price.",
    recallPrompt:
      "What does a share represent, and what does it never promise?",
    rowanExplanation:
      "A stock is an ownership claim with specific rights and real risks. It can gain or lose value; the symbol on a screen is never a promise.",
  },
  {
    title: "Buying and Selling",
    tarotKey: "the-hermit",
    accessibleLabel:
      "The Hermit as an optional memory aid for separating an order instruction from its execution; the card predicts nothing.",
    mythicMnemonic:
      "The Hermit’s lantern separates the order you send from the price you eventually receive.",
    factualSummary:
      "Learn what happens after an order is sent and the trade-off between market and limit orders.",
    sections: [
      {
        heading: "How a Trade Works",
        body:
          "A broker can route an order to an exchange, market maker, or electronic network. The market can move before the order arrives and executes.",
        uncertainty:
          "Routing, available quantity, market conditions, and venue rules can affect timing and execution.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/executing-order",
          title: "Executing an Order",
          publisher: "Investor.gov",
          claim:
            "Supports order-routing mechanics and the difference between a displayed price and an execution.",
        }],
      },
      {
        heading: "Market Orders vs Limit Orders",
        body:
          "A market order generally seeks prompt execution without fixing the price. A limit order sets a maximum buy price or minimum sell price, but it may never fill.",
        uncertainty:
          "A limit price is a boundary, not a promise of execution; a market order can fill away from the last displayed price.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/types-orders",
          title: "Types of Orders",
          publisher: "Investor.gov",
          claim:
            "Supports the price and execution trade-offs of market and limit orders.",
        }],
      },
    ],
    materialLimitations:
      "Displayed quotes, last trades, and electronic confirmations do not guarantee the next execution price or timing.",
    riskContext:
      "Fast or thin markets can create price changes, partial fills, delayed fills, or no fill for a limit order.",
    checkPrompt:
      "Which statement correctly compares market and limit orders?",
    correctOption:
      "A market order does not guarantee price; a limit order does not guarantee execution.",
    distractor: "Both order types guarantee the displayed quote.",
    recallPrompt:
      "What can a limit order control, and what can it not ensure?",
    rowanExplanation:
      "An order is an instruction. Market orders favor immediacy; limit orders set a price boundary but may not execute.",
  },
  {
    title: "ETFs and Diversification",
    tarotKey: "the-star",
    accessibleLabel:
      "The Star as an optional memory aid for spreading exposure across multiple holdings; the card predicts nothing.",
    mythicMnemonic:
      "A constellation uses many stars, yet the whole sky can still darken. More holdings do not make risk disappear.",
    factualSummary:
      "See how an ETF pools investments and why spreading exposure reduces some concentration risk—not every loss.",
    sections: [
      {
        heading: "What Is an ETF?",
        body:
          "A registered ETF pools investor money into a portfolio. ETF shares trade on an exchange, and their market price can differ from the portfolio’s net asset value.",
        uncertainty:
          "Read the objective, holdings, risks, fees, and structure; not every exchange-traded product is the same kind of ETF.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-2",
          title: "Exchange-Traded Funds (ETFs)",
          publisher: "Investor.gov",
          claim:
            "Supports registered ETF structure, exchange trading, documents, and material risks.",
        }],
      },
      {
        heading: "Why One Big Bet Can Wipe You Out",
        body:
          "Concentration makes one company, sector, or asset a larger source of the total outcome. Diversification spreads exposure across different investments.",
        uncertainty:
          "Counting positions is not enough: overlapping or narrowly focused holdings can still behave like one large bet.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/getting-started/asset-allocation",
          title: "Asset Allocation and Diversification",
          publisher: "Investor.gov",
          claim:
            "Supports diversification as a way to reduce some concentration risk without preventing loss.",
        }],
      },
    ],
    materialLimitations:
      "An ETF can be narrow, leveraged, concentrated, expensive, or trade away from net asset value. The label alone proves little.",
    riskContext:
      "ETF holdings can fall together, and diversification cannot prevent broad market loss.",
    checkPrompt: "What can diversification reasonably do?",
    correctOption:
      "Reduce some concentration risk without guaranteeing against loss.",
    distractor: "Guarantee that the portfolio never falls.",
    recallPrompt: "Why can an ETF with many holdings still be concentrated?",
    rowanExplanation:
      "An ETF is a pooled portfolio traded in shares. Diversification changes the shape of risk; it does not remove uncertainty.",
  },
  {
    title: "Read a Stock",
    tarotKey: "the-high-priestess",
    accessibleLabel:
      "The High Priestess as an optional memory aid for reading a company record beyond its quote; the card predicts nothing.",
    mythicMnemonic:
      "The High Priestess opens the record before interpreting the symbol. A quote is only one line in a much larger filing.",
    factualSummary:
      "Use a company’s business, revenue, profit, debt, and market capitalization to understand what the quote alone cannot show.",
    sections: [
      {
        heading: "Revenue, Profit, and Debt",
        body:
          "Revenue is money earned from the company’s activities; profit is what remains after relevant expenses. The balance sheet shows assets, liabilities, and equity, while notes explain important details.",
        uncertainty:
          "Definitions, accounting policies, one-time items, and reporting periods affect comparison. Read the filing and notes, not one isolated number.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/getting-started/researching-investments/how-read-10-k",
          title: "How to Read a 10-K",
          publisher: "Investor.gov",
          claim:
            "Supports the roles of financial statements, notes, business disclosure, and risk factors in a 10-K.",
        }],
      },
      {
        heading: "Share Price vs Market Cap",
        body:
          "Share price is the market price of one share. Market capitalization is that price multiplied by the total number of outstanding shares.",
        uncertainty:
          "A lower share price does not by itself mean a company is smaller or cheaper; outstanding share counts differ and can change.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/investing-basics/glossary/market-capitalization",
          title: "Market Capitalization",
          publisher: "Investor.gov",
          claim:
            "Supports the market-capitalization definition and its distinction from one share’s price.",
        }],
      },
    ],
    materialLimitations:
      "One ratio, one quarter, or one price cannot explain a company. Accounting judgments, share counts, and business conditions change.",
    riskContext:
      "Historical statements and market capitalization do not predict future performance or establish whether a price is attractive.",
    checkPrompt: "What does market capitalization measure?",
    correctOption: "Share price multiplied by total outstanding shares.",
    distractor: "The cash held in one brokerage account.",
    recallPrompt:
      "Why can two companies with different share prices still have similar market values?",
    rowanExplanation:
      "Start with what the company does and how its financial statements fit together. Then place the share price beside the outstanding share count.",
  },
  {
    title: "Protect Your Money",
    tarotKey: "justice",
    accessibleLabel:
      "Justice as an optional memory aid for comparing planned loss and hoped-for reward; the card predicts nothing.",
    mythicMnemonic:
      "Justice weighs the possible loss before the hoped-for reward. The scale measures a plan, not the future.",
    factualSummary:
      "Plan the possible dollar loss, understand stop-order limits, and treat 1:3 as an example—not a promise.",
    sections: [
      {
        heading: "Position Size: Decide Dollar Risk First",
        body:
          "Position size changes the dollar impact of the same price move. A risk plan begins by defining how much loss the position could create before deciding how many shares or contracts are involved.",
        uncertainty:
          "This is a planning concept, not a universal sizing formula or a recommendation for any person or security.",
        sources: [{
          url: "https://www.finra.org/investors/investing/investing-basics/risk",
          title: "Risk",
          publisher: "FINRA",
          claim:
            "Supports identifying investment risk and capacity for loss before making an investment decision.",
        }],
      },
      {
        heading: "Stop-Loss: What It Can and Cannot Do",
        body:
          "A stop order becomes a market order after its stop price is reached, so the execution price can differ. A stop-limit adds a price boundary but may not fill.",
        uncertainty:
          "No stop percentage is universal. Short-lived price moves, gaps, and venue rules can trigger or prevent executions in ways the stop price alone does not show.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins-15",
          title: "Stop, Stop-Limit, and Trailing Stop Orders",
          publisher: "Investor.gov",
          claim:
            "Supports stop-order conversion, execution-price risk, and the possibility that a stop-limit order does not execute.",
        }],
      },
      {
        kind: "neutral_example",
        heading: "Risk/Reward: Why 1:3 Is a Plan, Not a Promise",
        body:
          "A risk/reward ratio compares a planned loss boundary with a planned gain target. For example, 1:3 describes target size relative to risk; it says nothing about the probability of reaching either level.",
        uncertainty:
          "A favorable-looking ratio can still lose repeatedly, and prices may gap past either planned level. It is not a minimum rule or forecast.",
        sources: [{
          url: "https://www.finra.org/investors/investing/investing-basics/risk",
          title: "Risk",
          publisher: "FINRA",
          claim:
            "Supports treating risk and potential loss as uncertain rather than guaranteed by a planning ratio.",
        }],
      },
    ],
    materialLimitations:
      "No position-size rule, stop distance, stop percentage, or reward ratio is universally correct. Market gaps, liquidity, costs, and personal circumstances vary.",
    riskContext:
      "A stop order may execute far from its stop price; a stop-limit may not execute. Any position can lose more than expected in a fast market.",
    checkPrompt: "Which statement treats risk controls accurately?",
    correctOption:
      "They can define a plan, but they cannot guarantee the execution price or outcome.",
    distractor:
      "One fixed stop distance and a 1:3 target guarantee profitability.",
    recallPrompt:
      "Why is a 1:3 risk/reward plan not the same as a 75% chance of profit?",
    rowanExplanation:
      "Risk planning defines what would invalidate an idea and how much exposure the position creates. It does not tell the market what to do.",
  },
  {
    title: "Options, Simply",
    tarotKey: "the-chariot",
    accessibleLabel:
      "The Chariot as an optional memory aid for option-buyer rights and option-seller obligations; the card predicts nothing.",
    mythicMnemonic:
      "The Chariot has two reins: buyer rights and seller obligations. Time and volatility pull on both.",
    factualSummary:
      "Learn calls, puts, strike, premium, expiration, volatility, and Greeks without turning them into a trading signal.",
    sections: [
      {
        heading: "Calls and Puts",
        body:
          "A call gives its buyer the right to buy the underlying at the strike price by the expiration rules. A put gives its buyer the right to sell; option sellers take the corresponding obligations.",
        uncertainty:
          "Contract style and settlement rules matter, and exercising a contract is not the same as earning a profit.",
        sources: [{
          url:
            "https://www.finra.org/investors/investing/investment-products/options",
          title: "Options",
          publisher: "FINRA",
          claim:
            "Supports basic call and put rights, seller obligations, and material options risks.",
        }],
      },
      {
        heading: "Strike, Premium, and Expiration",
        body:
          "The strike is the contract’s exercise price, the premium is its purchase price, and expiration defines when the contract’s rights end. A buyer can lose the full premium.",
        uncertainty:
          "Being in the money does not automatically mean the buyer is profitable because the premium and other costs still matter.",
        sources: [{
          url:
            "https://www.finra.org/investors/investing/investment-products/options",
          title: "Options",
          publisher: "FINRA",
          claim:
            "Supports strike, premium, expiration, and the risk that an option buyer loses the premium.",
        }],
      },
      {
        heading: "Time, Volatility, and Greeks",
        body:
          "Option values respond to the underlying price, time remaining, and expected volatility. Delta, gamma, theta, and vega summarize different sensitivities; they are measurements, not predictions.",
        uncertainty:
          "Greeks change as inputs change and usually describe one factor while holding others constant. They do not fix an execution price or outcome.",
        sources: [{
          url:
            "https://www.finra.org/investors/investing/investment-products/options",
          title: "Options",
          publisher: "FINRA",
          claim:
            "Supports the role of time, volatility, and changing option-value sensitivities without treating them as forecasts.",
        }],
      },
    ],
    materialLimitations:
      "Option contracts differ by underlying, style, settlement, multiplier, expiration, and broker approval. A glossary is not a strategy.",
    riskContext:
      "An option buyer can lose the full premium. Some option sellers can face very large or theoretically unlimited losses and assignment obligations.",
    checkPrompt: "Which statement correctly describes an option premium?",
    correctOption:
      "It is the price the buyer pays and the seller receives for the contract rights and obligations.",
    distractor: "It guarantees the option finishes profitable.",
    recallPrompt:
      "What right does a call buyer receive, and what obligation does its seller accept?",
    rowanExplanation:
      "An option is a dated contract. The buyer pays a premium for a right; the seller accepts a corresponding obligation if exercised or assigned.",
  },
  {
    title: "News and Scams",
    tarotKey: "the-moon",
    accessibleLabel:
      "The Moon as an optional memory aid for checking dates, sources, and hype; the card predicts nothing.",
    mythicMnemonic:
      "The Moon brightens headlines while hiding their source. Check the date, publisher, conflict, and claim before reacting.",
    factualSummary:
      "Use the economic calendar for timing context, not direction, and recognize hype, fake gurus, and guaranteed-return pitches.",
    sections: [
      {
        heading: "Economic Calendar: What Can Move the Market",
        body:
          "Official calendars publish scheduled dates for economic-data releases and central-bank meetings. They help identify when new information may arrive; they do not predict the number or price direction.",
        uncertainty:
          "Release schedules can change, and market reactions depend on expectations, details, liquidity, and other events.",
        sources: [
          {
            url: "https://www.bls.gov/schedule/",
            title: "Schedule of Selected Releases",
            publisher: "U.S. Bureau of Labor Statistics",
            claim:
              "Supports checking official scheduled dates for major U.S. economic-data releases.",
          },
          {
            url:
              "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm",
            title: "Federal Open Market Committee Calendars",
            publisher: "Board of Governors of the Federal Reserve System",
            claim:
              "Supports checking official scheduled dates for FOMC meetings and releases.",
          },
        ],
      },
      {
        heading: "News, Hype, Fake Gurus, and FOMO",
        body:
          "Social posts can be inaccurate, paid, anonymous, or designed to create false urgency. Never treat popularity, screenshots, or a confident personality as independent evidence.",
        uncertainty:
          "A red flag prompts verification; it is not by itself a legal finding. Check the source and professional background independently.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/social-media-stock-scams",
          title: "Social Media and Stock Tip Scams",
          publisher: "Investor.gov",
          claim:
            "Supports recognized social-media fraud tactics, urgency, impersonation, and independent verification.",
        }],
      },
    ],
    materialLimitations:
      "A scheduled release or news item can coincide with market movement without explaining it or predicting the direction.",
    riskContext:
      "Urgency, impersonation, fake testimonials, guaranteed returns, and unsolicited messages are recognized fraud warning signs.",
    checkPrompt: "Which claim is a recognized fraud warning sign?",
    correctOption:
      "High guaranteed returns with little risk and pressure to act immediately.",
    distractor:
      "A dated official release calendar with no price forecast.",
    recallPrompt:
      "What can an economic calendar tell you, and what can it not predict?",
    rowanExplanation:
      "Calendars show when official information is scheduled. They do not tell you how a market will interpret the number or what to buy.",
  },
  {
    title: "Build Your System",
    tarotKey: "justice",
    accessibleLabel:
      "Justice as an optional memory aid for recording the same questions before and after a decision; the card predicts nothing.",
    mythicMnemonic:
      "Justice writes the same questions before every decision. A consistent record makes hindsight easier to challenge.",
    factualSummary:
      "Turn the course into a short before-trade checklist, then use paper practice and a journal to review your process.",
    sections: [
      {
        heading: "Your Before-Trade Checklist",
        body:
          "Record what the instrument is, the factual reason for the decision, the source and date, the possible loss, and what evidence would invalidate the idea. Do this before the outcome is known.",
        uncertainty:
          "A checklist supports consistency but cannot establish suitability, probability, or a guaranteed result.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/general-resources/investor-preparedness-checklist",
          title: "Investor Preparedness Checklist",
          publisher: "Investor.gov",
          claim:
            "Supports research, risk awareness, independent verification, and avoiding pressured decisions.",
        }],
      },
      {
        heading: "Paper Trade, Journal, Review",
        body:
          "Practice the written process without risking money, record the assumed entry and exit, then compare the plan with what happened. Focus on whether the rules were followed—not only profit or loss.",
        uncertainty:
          "Simulations can omit realistic fills, liquidity, fees, taxes, stress, and mistakes, so paper performance is not live evidence.",
        sources: [{
          url:
            "https://www.investor.gov/introduction-investing/getting-started/investing-your-own/online-investing",
          title: "Online Investing",
          publisher: "Investor.gov",
          claim:
            "Supports researching risks and understanding the limits of online tools before committing money.",
        }],
      },
    ],
    materialLimitations:
      "A checklist, journal, or simulation cannot reproduce every execution, emotion, cost, tax, or market condition.",
    riskContext:
      "A disciplined process can still lose money. Paper results and past results do not guarantee live performance.",
    checkPrompt: "What is the purpose of a trading journal?",
    correctOption:
      "To preserve the original plan and review decisions without rewriting them after the outcome.",
    distractor:
      "To prove that future trades will match past paper results.",
    recallPrompt:
      "Which facts should a before-trade record capture before the outcome is known?",
    rowanExplanation:
      "A useful system records the claim, source, risk boundary, and result consistently. It evaluates the process without pretending to predict the next trade.",
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
      evidence: section.sources.map((source, sourceIndex) => ({
        ordinal: sourceIndex + 1,
        canonical_url: source.url,
        source_title: source.title,
        publisher: source.publisher,
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
  session: {
    id: "63000000-7000-4000-8000-000000000001",
    state: "active",
    started_at: observedAt,
    last_action_at: observedAt,
    explicit_start: false,
    replacement_of_session_id: null,
  },
  theme: {
    id: "63000000-6000-4000-8000-000000000001",
    key: "constellation-map",
    title: "StarPath Foundations",
    horoscope_frame:
      "Open any Part in any order. Celestial imagery is a memory aid, never evidence or a forecast.",
    factual_focus:
      "Eight open Parts and nineteen short lessons covering definitions, risk, records, verification, and process.",
    accessible_label:
      "A downward suggested route through eight open educational Parts and nineteen short lessons.",
  },
  progress: {
    current_node_ordinal: 1,
    version: 1,
    updated_at: observedAt,
  },
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
