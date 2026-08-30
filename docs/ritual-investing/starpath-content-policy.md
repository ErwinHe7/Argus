# Starpath no-advice content policy

- Policy version: `starpath-no-advice-v1`
- Artifact status: engineering-complete; legal production approval pending (RC3)
- Classification: `education_general`
- Initial jurisdiction: United States
- Product owner: Starpath factual investment-literacy editorial

This policy governs every member-facing Starpath field, including titles, tarot and horoscope mnemonic language, factual sections, examples, limitations, risks, knowledge checks, recall, and Rowan explanations. It is a product release control as well as an editorial standard. It does not replace legal advice or a jurisdiction-specific legal determination.

## Non-negotiable boundary

Starpath explains facts. It does not tell a member what to buy, sell, hold, avoid, rank, allocate, deposit, trade, or select. It does not assess suitability, infer investment intent, forecast prices or returns, compare securities for desirability, or construct a portfolio.

Tarot, astrology, constellations, and horoscope language may be used only as a clearly labeled memory device. They are never evidence, causation, analysis, a prediction, a market signal, a recommendation, or a reason to act. Birth data, holdings, balances, orders, questionnaire answers, stated preferences, and brokerage activity are not inputs to lesson or theme selection.

Allowed content includes:

- definitions, mechanics, disclosures, and dated public facts from primary official sources;
- neutral or synthetic examples that demonstrate how to read a field or distinguish two terms;
- uncertainty, material limitations, and risk context presented alongside the claim;
- comprehension questions whose answer is contained in the lesson;
- quoted scam language when the surrounding copy unambiguously identifies it as a warning sign;
- deterministic Rowan explanations that restate only the reviewed lesson.

Prohibited content includes:

- subjective desirability, rankings, picks, or claims that a security or product is best, right, perfect, safe, cheap, expensive, attractive, or suitable;
- imperative or implied buy, sell, hold, funding, deposit, allocation, or timing instructions;
- individualized guidance or lesson selection derived from a member profile or financial activity;
- forecasts, price targets, expected returns, guaranteed outcomes, or tarot/astrology treated as financial evidence;
- questions that solicit an investment preference, intended action, risk tolerance, desired security, or portfolio choice;
- celebrations, prompts, or rewards tied to investing, depositing, funding, or trading behavior.

## Required lesson structure

Each revision must bind the exact policy version and contain all of the following as separate typed fields:

1. Stable lesson and pathway identity.
2. Tarot guide key and accessible memory-aid label.
3. Mythic mnemonic with no factual or predictive authority.
4. Factual summary and one or more factual or neutral-example sections.
5. Material limitations, risk context, and uncertainty.
6. HTTPS primary evidence with publisher, source-observed, retrieved, effective when applicable, and current-until dates plus a bounded claim summary.
7. A comprehension-only check with exactly one factually correct answer.
8. A non-blocking recall prompt.
9. A deterministic Rowan explanation.
10. `education_general` classification.

The database structural and lexical validator is defense in depth. It rejects missing typed fields and a bounded list of common recommendation phrases, but it cannot determine truth, context, completeness, or suitability. Human factual and compliance review remains mandatory.

## Review and correction

Submission seals the canonical revision hash and opens one factual and one compliance request against that hash and `policy_version`. The author cannot review their own high-trust revision. A reviewer must have the exact discipline scope, record an explicit reason, and use an AAL2 staff session. One person may perform both reviews only when independently provisioned for both scopes.

A rejection or change request closes the sealed revision. A correction creates a successor revision and requires fresh factual and compliance attestations; prior decisions, evidence, render documents, publication events, and withdrawal history remain immutable and attributable. Materially false, stale, incomplete, or misleading published content is withdrawn from new sessions, then replaced through the same workflow.

## Legal and production gate

Routine lessons require factual and compliance review. Legal counsel validates this exact policy version before production publication. A renewed legal review is required before any of these R20 triggers enters product scope:

- personalization or use of member, astrology, brokerage, holdings, balance, order, or preference data;
- security or product comparisons, rankings, or suitability language;
- monetization, paid placement, affiliate economics, or issuer sponsorship;
- brokerage integration, funding, investment-action prompts, or trading controls;
- a new jurisdiction, classification, or materially different education format.

Production remains fail-closed when legal approval is absent, expired, superseded, invalidated, for another jurisdiction, or does not cover the current trigger snapshot. Beta engineering and factual/compliance review do not constitute production legal approval.

## Evidence retained for each release

- policy version, canonical document hash, approval identity/time, effective/expiry window, jurisdiction set, and R20 trigger snapshot;
- authored revision, author, canonical content hash, render document, and source dates;
- factual and compliance request/decision identities, scopes, disciplines, reasons, policy versions, sealed hashes, and timestamps;
- manifest version, exact eight revision IDs, ordered pathway positions, reviewed theme IDs, environment, jurisdiction, publisher, reason, and publication time;
- supersession, withdrawal, and correction lineage without mutation of prior evidence.

