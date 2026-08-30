# Starpath initial curriculum v1

This is the review artifact for the first eight-node Starpath manifest. It is original Argus copy built from primary public sources. It is not a published database manifest and does not authorize beta or production release. Import and publication remain pending RC2 attestations; production additionally requires RC3 legal approval of `starpath-no-advice-v1`.

Artifact authority:

- Curriculum version: `starpath-curriculum-v1`
- Policy version: `starpath-no-advice-v1`
- Classification: `education_general`
- Environment candidate: beta
- Jurisdiction: US
- Source observation and retrieval date: 2026-08-30
- Evidence freshness review date: 2026-11-28
- Manifest shape: four ordered pathways, two lessons each

Each recorded SHA-256 is computed from the UTF-8 identity string:

`curriculum_version|policy_version|node|stable_key|factual_summary|canonical_source_urls`, with multiple source URLs joined by `|`.

The import receipt must record this artifact hash, the database revision ID and canonical payload hash, and proof that the resulting typed projection matches the reviewed fields below. The database payload hash, rather than this pre-import identity hash, is the publication authority.

## Reviewed session-theme pool

| Key | Mythic frame | Factual focus | Accessible label |
|---|---|---|---|
| `constellation-map` | “Walk a constellation one observed fact at a time.” This is a memory frame, not a horoscope or forecast. | Terms, risk, documents, and verification. | A downward constellation path connecting eight factual lessons. |
| `mercury-glossary` | “Mercury carries names between the stars.” This is a vocabulary mnemonic only. | Distinguishing labels, disclosures, and sources. | A vocabulary-themed path with no astrological prediction. |

## Pathway 1 — Core terms and markets

### Node 1 — The Share Sigil

- Stable key: `share-sigil`; position: 1.1; tarot key: `the-magician`
- Accessible guide: The Magician as a memory aid for a documented unit; the card predicts nothing.
- Mythic mnemonic: A sigil marks one defined unit. Here it helps distinguish an ownership unit from a promise of profit.
- Factual summary: A share of common stock represents an ownership interest in a company.
- Factual section: A company may issue shares to raise capital. Existing shares may later trade between market participants. Common-stock rights vary and can include voting or dividends, but neither a dividend nor a gain is guaranteed.
- Uncertainty: Rights depend on the security class, issuer documents, corporate actions, and applicable law.
- Material limitations: The label “stock” alone does not establish voting rights, dividend terms, seniority, liquidity, or future value.
- Risk context: A stock price can fall; in liquidation, common shareholders may receive nothing after higher-priority claims.
- Evidence: [Investor.gov — Stocks](https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks), U.S. Securities and Exchange Commission; supports ownership and common-stock characteristics; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “Which statement describes common stock?” Correct: “It records an ownership interest whose specific rights depend on the issue.” Distractor: “It guarantees a dividend and a higher future price.” Explanation: ownership and guaranteed outcome are different concepts.
- Recall: What does one share represent, and what does it not promise?
- Rowan: A share is a documented ownership unit. Its exact rights come from the issue; the symbol on a screen does not promise income or price appreciation.
- Pre-import identity SHA-256: `40fba0490714ef740bad070be59051ff188bf0e09e9904f26c5641331e17561a`

### Node 2 — The Market Lantern

- Stable key: `market-lantern`; position: 1.2; tarot key: `the-hermit`
- Accessible guide: The Hermit’s lantern as a memory aid for seeing one quoted field at a time; it predicts nothing.
- Mythic mnemonic: A lantern illuminates separate labels: bid, ask, last trade, and order instruction are related but not interchangeable.
- Factual summary: Quotes and orders describe prices and execution instructions; a displayed or last-traded price is not an execution promise.
- Factual section: The bid is a quoted buying price and the ask is a quoted selling price; their difference is the spread. A market order generally seeks immediate execution but not a fixed execution price. A limit order sets a price boundary but may not execute. The last trade reports a completed transaction, not necessarily the next available price.
- Uncertainty: Quotes cover specified quantities, prices can change, routing takes time, and order types or handling rules differ by broker and venue.
- Material limitations: A quote or last-traded price does not show every available order, future liquidity, or the eventual price of a submitted order.
- Risk context: Fast-moving or thin markets can produce partial fills, no fill for a limit order, or a market-order price different from the displayed quote.
- Evidence: [Investor.gov — Types of Orders](https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/types-orders) and [Investor.gov — Executing an Order](https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/executing-order), U.S. Securities and Exchange Commission; supports order mechanics, timing, and spread; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “Which statement separates execution from price?” Correct: “A market order may execute without guaranteeing its execution price.” Distractor: “The last trade fixes the next execution price.” Explanation: recorded, quoted, and executed prices are distinct.
- Recall: What does a limit order control, and what can it not ensure?
- Rowan: An order carries instructions. Market and limit orders make different trade-offs between immediacy, price boundaries, and the possibility of no execution.
- Pre-import identity SHA-256: `3db36a81d0a590cc1e0e8a9732e67765759c125493bf0953080ef24ebf75c26a`

## Pathway 2 — Risk, diversification, and fees

### Node 3 — The Many-Star Shield

- Stable key: `many-star-shield`; position: 2.1; tarot key: `the-star`
- Accessible guide: The Star as a memory aid for many distinct points rather than one concentrated point; it predicts nothing.
- Mythic mnemonic: A constellation needs more than one star, but a larger pattern is not an invulnerable shield.
- Factual summary: Diversification spreads exposure across investments and can reduce concentration risk, but it cannot prevent market loss.
- Factual section: Concentration makes one issuer, sector, or asset a larger source of total outcome. Diversification distributes exposure. A fund may hold many assets, but a narrowly focused fund or overlapping funds may still be concentrated.
- Uncertainty: Correlations and holdings change. The number of positions alone does not measure how differently they behave.
- Material limitations: Diversification cannot guarantee a gain, eliminate broad market risk, or establish that a particular allocation is suitable.
- Risk context: Multiple holdings can decline together, and fund structure, overlap, liquidity, or fees can add other risks.
- Evidence: [Investor.gov — Diversify Your Investments](https://www.investor.gov/introduction-investing/investing-basics/save-and-invest/diversify-your-investments) and [Asset Allocation and Diversification](https://www.investor.gov/introduction-investing/getting-started/asset-allocation), U.S. Securities and Exchange Commission; supports concentration/diversification mechanics and limitations; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “What can diversification do?” Correct: “Spread exposure and reduce some concentration risk without preventing loss.” Distractor: “Guarantee that market declines cannot reduce value.”
- Recall: Why can a fund with many positions still be concentrated?
- Rowan: Diversification describes how exposure is spread. It changes the shape of some risks; it does not erase uncertainty or loss.
- Pre-import identity SHA-256: `91f3a2824f481b114bad969c3271af8e4ae4f791f4d334508134fd3ad8f1f492`

### Node 4 — The Fee Eclipse

- Stable key: `fee-eclipse`; position: 2.2; tarot key: `the-moon`
- Accessible guide: The Moon as a memory aid for costs that can be less visible; it predicts nothing.
- Mythic mnemonic: An eclipse can hide part of the light. Fees can reduce the value that remains, even when a quoted percentage looks small.
- Factual summary: Transaction, account, advisory, and fund operating costs reduce the value retained from an investment over time.
- Factual section: Costs can include commissions, account charges, asset-based advice fees, shareholder fees, and annual fund operating expenses. A fund expense ratio expresses annual operating expenses as a percentage of average net assets. Recurring costs also reduce the amount left to participate in later gains or losses.
- Neutral example: With all other inputs held constant, applying a recurring fee leaves a smaller ending value than applying no fee. This comparison illustrates arithmetic only and is not a forecast.
- Uncertainty: Actual charges depend on agreements, product disclosures, account activity, share class, intermediaries, and costs not included in a prospectus fee table.
- Material limitations: Expense ratio does not include every possible transaction, brokerage, tax, spread, premium/discount, or advisory cost.
- Risk context: A low stated cost does not remove investment risk, and costs can apply during periods of negative performance.
- Evidence: [Investor.gov — How Fees and Expenses Affect Your Investment Portfolio](https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/updated) and [Mutual Fund and ETF Fees and Expenses](https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/mutual-fund-and-etf-fees-and-expenses-investor-bulletin), U.S. Securities and Exchange Commission; supports fee categories and retained-value effect; published 2025-07-23, observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “What does an expense ratio describe?” Correct: “Annual fund operating expenses as a percentage of average net assets.” Distractor: “Every cost that any holder can incur.”
- Recall: Why can a recurring fee affect more than the amount deducted in its first year?
- Rowan: A fee is a cost with a defined basis and frequency. Reading its label, rate, exclusions, and source reveals what the number covers and what it leaves out.
- Pre-import identity SHA-256: `71db558534f028d4c6f581c7a68c44fe61a25f4d7fe1a02f872d044820ff25bf`

## Pathway 3 — Reading factual information

### Node 5 — The Filing Grimoire

- Stable key: `filing-grimoire`; position: 3.1; tarot key: `the-high-priestess`
- Accessible guide: The High Priestess as a memory aid for opening a structured public record; it predicts nothing.
- Mythic mnemonic: A grimoire has named chapters. A Form 10-K also has defined sections whose labels tell the reader what type of disclosure follows.
- Factual summary: A Form 10-K describes a public company’s business, significant risks, and audited financial statements.
- Factual section: Item 1 describes the business. Item 1A presents significant risk factors. Item 7 contains management’s discussion and analysis. Item 8 contains audited financial statements, including income statements, balance sheets, cash-flow statements, stockholders’ equity, and notes. Public filings are available through EDGAR.
- Uncertainty: The company prepares the filing, estimates and judgments affect reported amounts, risks can change after the reporting period, and SEC filing or review is not an endorsement of an issuer.
- Material limitations: One line item or one reporting period does not explain a company by itself. Notes, accounting policies, dates, amendments, and later filings provide context.
- Risk context: Filings may contain forward-looking statements and identified risks; historical statements do not establish future outcomes.
- Evidence: [Investor.gov — How to Read a 10-K](https://www.investor.gov/introduction-investing/getting-started/researching-investments/how-read-10-k) and [How to Read a 10-K/10-Q](https://www.investor.gov/introduction-investing/general-resources/news-alerts/alerts-bulletins/investor-bulletins/how-read), U.S. Securities and Exchange Commission; supports section structure, statements, and SEC role; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “Where are audited income, balance-sheet, and cash-flow statements found in a 10-K?” Correct: “Financial Statements and Supplementary Data.” Distractor: “The stock-price quote.”
- Recall: What different questions do Business, Risk Factors, and Financial Statements answer?
- Rowan: The filing is a dated, structured disclosure. Its headings help separate the company’s business description, risks, management discussion, and audited numbers.
- Pre-import identity SHA-256: `815bac5d09d90a6fe361c9188b3814eb1ddf45793b1940131a64066dde17c415`

### Node 6 — The Fund and Bond Map

- Stable key: `fund-bond-map`; position: 3.2; tarot key: `the-chariot`
- Accessible guide: The Chariot as a memory aid for reading two labeled routes—fund ownership and issuer debt; it predicts nothing.
- Mythic mnemonic: A map separates routes before comparing their labels. An ETF share and a bond describe different legal and economic structures.
- Factual summary: Fund documents describe a fund portfolio, objective, risks, and expenses; bond terms describe a debt claim and its payment schedule.
- Factual section: A registered ETF pools assets; each share represents an interest in its portfolio. Its prospectus describes objectives, strategies, risks, and a standardized fee table, while holdings and shareholder reports add dated detail. A bond is debt issued by a government, municipality, or corporation. Terms can include face value, coupon, maturity, and yield.
- Factual section: Bond risks can include issuer credit/default, interest-rate, inflation, and liquidity risk. A bond sold before maturity may trade above or below face value; yield and price are related but not identical fields.
- Uncertainty: Fund holdings, index methods, premiums/discounts, yields, credit conditions, market rates, and liquidity change over time.
- Material limitations: A product label does not establish diversification, cost, tax treatment, credit quality, liquidity, or future return. Registered ETFs are not the same as every exchange-traded product.
- Risk context: ETF holdings can lose value. Bond issuers can default, and changing rates or liquidity can change a bond’s market price.
- Evidence: [Investor.gov — Exchange-Traded Funds](https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-2) and [Investor.gov — Bonds](https://www.investor.gov/introduction-investing/investing-basics/investment-products/bonds-or-fixed-income-products/bonds), U.S. Securities and Exchange Commission; supports fund and bond structures/risks; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “Which pair names a bond term and a bond risk?” Correct: “Maturity and issuer credit risk.” Distractor: “Expense ratio and guaranteed gain.”
- Recall: Which documents or fields describe what a fund holds and what a bond promises to pay?
- Rowan: Start with structure: a fund share points to a portfolio; a bond points to an issuer’s debt obligation. Then read each document’s dated terms, costs, and risks.
- Pre-import identity SHA-256: `01b4d4f53b76b2ea5ab910124cf1e2f7baaa1f2381413a54420a87314589d376`

## Pathway 4 — Scams and verification

### Node 7 — The False Sun

- Stable key: `false-sun`; position: 4.1; tarot key: `the-sun`
- Accessible guide: The Sun as a memory aid for checking whether a bright claim is supported; it predicts nothing.
- Mythic mnemonic: A painted sun can look bright without producing light. A vivid pitch can create emotion without providing verifiable evidence.
- Factual summary: Promises of high or guaranteed returns with little risk, urgency, false credentials, and unsolicited pitches are recognized fraud warning signs.
- Factual section: Official investor-protection material identifies warning signs including unlicensed people, exaggerated credentials, “risk-free” or guaranteed-return claims, social-pressure pitches, urgency, fake testimonials, unsolicited contact, and unusual payment requests.
- Uncertainty: A warning sign is not by itself a legal finding. Fraud determinations depend on evidence and the relevant authority.
- Material limitations: Familiarity, professional-looking media, group membership, popularity, or a confident tone do not independently verify a claim.
- Risk context: Fraud can cause financial loss, identity theft, unauthorized transfers, or loss of access to funds; recovering transferred assets may be difficult.
- Evidence: [Investor.gov — Red Flags of Investment Fraud Checklist](https://www.investor.gov/protect-your-investments/fraud/how-avoid-fraud/red-flags-investment-fraud-checklist) and [Protect Your Money: How to Avoid Investment Scams](https://www.investor.gov/protect-your-investments/fraud/protect-your-money), U.S. Securities and Exchange Commission; supports listed warning signs; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “Which statement is a recognized warning sign?” Correct: “A pitch combines high guaranteed returns, little risk, and pressure to act immediately.” Distractor: “A dated public filing lists material risks.”
- Recall: Name two warning signs that concern how a pitch is presented rather than what security it names.
- Rowan: Warning signs prompt verification; they are not predictions. Separate the emotional pressure from the claim, then look for independent records and dates.
- Pre-import identity SHA-256: `5509b193b6dcb8b61ff494cd05048ef413076a5c278c85d810f7b94dcae61c7e`

### Node 8 — The Verification Compass

- Stable key: `verification-compass`; position: 4.2; tarot key: `justice`
- Accessible guide: Justice as a memory aid for matching a claim to an independent record; it predicts nothing.
- Mythic mnemonic: A compass checks direction against a reference point. Verification checks a claim against a dated official record rather than intuition or popularity.
- Factual summary: Official filing, registration, disciplinary, source-date, conflict, and reporting records can be checked independently.
- Factual section: EDGAR provides company filings. IAPD provides adviser registration, business, fee, conflict, and disciplinary information; BrokerCheck provides broker and firm background and disciplinary information. Source title, publisher, observation date, and effective period help identify which claim a record supports. The SEC provides a Tips, Complaints, and Referrals channel for suspected securities-law violations.
- Uncertainty: Registration does not guarantee honesty, competence, performance, or the merits of a security. Records can be amended, differently scoped, or incomplete for a particular question.
- Material limitations: One database does not cover every person, product, jurisdiction, conflict, or allegation. A search result is not a recommendation or a legal conclusion.
- Risk context: Imposters can misuse real names or registration details, and stale screenshots can omit later changes or discipline.
- Evidence: [Investor.gov — Ask and Check](https://www.investor.gov/introduction-investing/getting-started/researching-investments/ask-and-check) and [SEC — Report Possible Securities Law Violations](https://www.sec.gov/submit-tip-or-complaint/report-possible-securities-law-violations); supports IAPD/BrokerCheck fields and SEC reporting path; observed/retrieved 2026-08-30; current-until 2026-11-28.
- Check: “What can BrokerCheck or IAPD establish?” Correct: “Registration and disclosed background or disciplinary information within the tool’s scope.” Distractor: “That a promoted investment will gain value.”
- Recall: Which four metadata fields help bind a factual claim to a source?
- Rowan: Verification means matching a specific claim to the appropriate current record, noting the record’s scope and date, and keeping the result separate from any investment decision.
- Pre-import identity SHA-256: `b379f3483a2a46ab946f85d25ce44944767c98bb9f71de1f6f8a6b878bd7f1e9`

## Publication evidence checklist

The content owner records one import receipt per node with stable lesson ID, exact revision ID, canonical database payload hash, the pre-import identity hash above, and projection comparison output. The factual reviewer records source/date/claim checks. The compliance reviewer records policy and field-separation checks. The publisher verifies eight distinct approved revisions in exact 1.1 through 4.2 order, at least one reviewed theme, the beta/US authority, and a current evidence window.

No receipt, review, approval, or manifest ID has been fabricated in this artifact. Until RC2 principals complete those records, the publication milestone is open.
