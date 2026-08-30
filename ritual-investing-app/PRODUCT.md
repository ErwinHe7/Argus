# Product

## Register

product

## Platform

adaptive

## Users

Gen Z and millennial women who want investing to feel approachable without losing evidence, uncertainty, or control. They use Argus for short daily rituals, deeper research, and deliberate reviews of an existing Webull brokerage relationship.

## Product Purpose

Create an adaptive iOS, Android, and mobile-web investing companion where tarot and astrology make market research and factual investment education emotionally approachable while evidence, uncertainty, and limitations remain inspectable. Starpath teaches reviewed definitions through mythic memory aids; it never recommends, ranks, predicts, personalizes what to invest in, or turns lesson behavior into investment intent. The clearly labeled public web beta preserves supported member and privacy behavior against dedicated non-production beta services; it does not make unfinished brokerage capabilities functional. Members may eventually connect an existing Webull account, understand timestamped brokerage state, and explicitly confirm only supported manual order actions after their separate launch gates pass. Argus is not a brokerage, does not open or fund accounts, and does not maintain a second brokerage ledger.

## Authority Model

- Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders.
- Argus is authoritative for ritual, editorial, community, factual-learning, preference, and privacy state, including Daily Ritual, Starpath, discovery, Circle, Grimoire, Founders' Coven, Intentions, and Future Mirror scenarios.
- Release controls are authoritative for which member branches exist in a trusted environment. Starpath consumes that server-authoritative capability contract but does not own its feature-flag table, evaluation engine, or operator workflow. Missing, expired, unknown, or downgraded capability data fails closed.
- Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Flutter calls the versioned Argus API for application and brokerage data and uses Supabase directly only for Auth and approved Storage transport.
- The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated. It is a separate product surface, not a mode or ledger in the production member app.
- Cloudflare Pages continues to serve the unchanged static landing and standalone Demo assets. Cloudflare Workers Static Assets may deliver the compiled member web beta at the apex, but Cloudflare receives no Auth, application-data, database, provider, or stateful backend authority.
- The member web beta is invite-first and uses only dedicated non-production beta Supabase Auth, the versioned beta Argus API, and canonical private tables. Self-service signup remains unavailable until hosted email confirmation, CAPTCHA or equivalent abuse protection, and the invitation, recovery, deletion, rate-limit, and support evidence gates pass.
- Supported routes are `beta-backed`; privacy export is API-backed, and deletion uses the idempotent automated path or an API-backed request/status path with a verified manual completion SLA. Every brokerage connection, read, funding action, and order mutation is visibly `unavailable` and fail-closed. The `standalone Demo handoff` is the only synthetic experience and is always explicit and visibly labeled.
- Every authenticated surface identifies the experience as a public beta, states that live brokerage connections, funding, and orders are unavailable, and keeps privacy, support, about, beta-feedback, and legal information reachable.

## Brand Personality

Mystic, discerning, intimate. The product should feel composed and observant rather than breathless, juvenile, or sales-driven. Rowan brings warmth and clarity, but the member always retains agency.

## Anti-references

- Generic navy-and-green brokerage dashboards with mystical decoration added afterward.
- Juvenile horoscope apps, novelty occult clip art, or an uncurated “Etsy witch” collage.
- Hidden market influence, supernatural guarantees, stale brokerage state presented as current, or disclosures designed to escape notice.
- Funding, recurring execution, autonomous trading, rebalancing execution, account-opening, or custody claims.
- Romance, urgency, jealousy, exclusivity, or sexual pressure used to influence a financial decision.

## Design Principles

- Ritual before metrics: begin with an emotionally legible reading, then let evidence deepen it.
- Evidence in one gesture: observations, timing, uncertainty, limitations, provider timestamps, fetch timestamps, and freshness remain adjacent and inspectable.
- Provider truth without a second ledger: stale or unavailable brokerage projections are labeled; mutations require fresh authoritative capability and restriction checks.
- Original world, familiar behavior: bespoke art and language live inside platform-appropriate navigation, accessibility, and controls.
- Counsel without coercion: Rowan explains and reassures; he never decides, pressures, or impersonates an adviser.
- Rowan cannot issue financial commands and cannot receive Webull credentials, raw provider payloads, balances, or positions as prompt context.
- Myth is memory, not evidence: tarot, astrology, and horoscope language may make a reviewed fact memorable but can never supply causation, probability, suitability, a forecast, or a security choice.
- Demonstrate honestly: synthetic state exists only in the standalone Demo and remains visibly marked Demo.

## Starpath Product Contract

- Starpath is available only to signed-in members and contains exactly eight ordered nodes arranged as four pathways of two lessons.
- The beta branch order is Ritual → Starpath → Discover → Coven → You. The production branch order is Ritual → Starpath → You; Discover and Coven are absent from tabs, restoration, deep links, and protected APIs.
- A member explicitly begins a reviewed manifest. Progress is server-authoritative, sequential, and non-punitive: wrong answers retain every control, consume no life, and do not lock the member out.
- Each node keeps the mythic mnemonic visibly separate from the factual claim, source and observation dates, uncertainty, material limitations, risk context, and knowledge check.
- Rowan may reveal only the deterministic, reviewed explanation pinned to that lesson revision. There is no free-form Starpath prompt, recommendation, prediction, or progress mutation through Rowan.
- Starpath does not read holdings, balances, orders, investor-profile answers, astrology profile, security preferences, or inferred intent. Its primary measurement is an aggregate return-to-learning definition, `learning_retention_within_7d_v1`; it has no product target until the product owner sets one after a real baseline exists.
- Legal counsel approves the versioned no-advice policy before production publication and again when a defined expansion trigger changes the risk boundary. Routine factual lesson revisions receive distinct factual and compliance review rather than individual legal approval.

## Accessibility & Inclusion

Target WCAG 2.2 AA contrast and semantics while respecting iOS Dynamic Type, Android font scaling, VoiceOver, TalkBack, reduced-motion settings, platform back gestures, safe areas, and minimum 44pt iOS / 48dp Android touch targets. Information, authority, freshness, and risk must never rely on color alone. Astrology personalization remains optional, and tarot remains fully usable without birth details.
