# Product

## Register

product

## Platform

adaptive

## Users

Gen Z and millennial women who want investing to feel approachable without losing evidence, uncertainty, or control. They use Argus for short daily rituals, deeper research, and deliberate reviews of an existing Webull brokerage relationship.

## Product Purpose

Create an adaptive iOS, Android, and mobile-web investing companion where tarot and astrology make market research and factual investment education emotionally approachable while evidence, uncertainty, and limitations remain inspectable. Starpath teaches reviewed definitions through mythic memory aids; it never recommends, ranks, predicts, personalizes what to invest in, or turns lesson behavior into investment intent. The clearly labeled public web beta preserves supported member and privacy behavior against dedicated staging services; it does not make unfinished brokerage capabilities functional. Members may eventually connect an existing Webull account, understand timestamped brokerage state, and explicitly confirm only supported manual order actions after their separate launch gates pass. Argus is not a brokerage, does not open or fund accounts, and does not maintain a second brokerage ledger.

## Authority Model

- Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders.
- Argus is authoritative for ritual, editorial, community, factual-learning, preference, and privacy state, including Daily Ritual, Starpath, discovery, Circle, Grimoire, Founders' Coven, Intentions, and Future Mirror scenarios.
- Release controls are authoritative for which member branches exist in a trusted environment. Starpath consumes that server-authoritative capability contract but does not own its feature-flag table, evaluation engine, or operator workflow. Missing, expired, unknown, or downgraded capability data fails closed.
- Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Flutter calls the versioned Argus API for application and brokerage data and uses Supabase directly only for Auth and approved Storage transport.
- The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated. It is a separate product surface, not a mode or ledger in the production member app.
- Cloudflare Pages continues to serve the unchanged static landing and standalone Demo assets. Cloudflare Workers Static Assets may deliver the compiled member web beta at the apex, but Cloudflare receives no Auth, application-data, database, provider, or stateful backend authority.
- The member web public beta uses regular email-and-password signup against only staging Supabase Auth, the public-beta Argus API, and canonical private tables. The provider's historical physical branch label `beta` maps only to logical staging. Invitation-only entry is not part of the product; public promotion remains gated on hosted confirmation, recovery, abuse, deletion, rate-limit, and support evidence.
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

- Starpath presents two separate learning universes: Invest and Trade. A member may switch freely between them; access and progress are modeled separately rather than combined into one percentage.
- Invest contains exactly eight ordered constellations with nineteen short factual lessons. Every constellation and lesson is browse-accessible as soon as Starpath is available; progress never gates reading access. The curriculum is: `The Market` — `What Is Investing?`, `What Is a Stock?`, `Why Do Stock Prices Move?`, `What Is a Broker?`; `The S&P 500` — `What Is an Index?`, `What Is the S&P 500?`, `SPX vs SPY vs VOO`; `ETFs & Diversification` — `What Is an ETF?`, `One Stock vs a Basket`; `How to Buy` — `Buy and Sell`, `Market Order vs Limit Order`; `Your Portfolio` — `What Is a Portfolio?`, `Concentration`; `Understanding Risk` — `Price Risk and Volatility`, `Drawdown and Time Horizon`; `Understanding a Company` — `What Does the Company Sell?`, `Revenue and Profit`; `Practice Your First Investment` — `Know What You’re Buying`, `Preview a Sample Order`.
- Trade is currently a roadmap-only shell covering charts, price movement, execution, risk management, options, futures, and crypto. It does not fabricate lesson progress, pricing, or entitlement state, and it never sends Invest progress mutations.
- The beta branch order is Ritual → Starpath → Discover → Coven → You. The production branch order is Ritual → Starpath → You; Discover and Coven are absent from tabs, restoration, deep links, and protected APIs.
- A member may browse before starting or completing anything. Starting a reviewed manifest establishes the server-authoritative suggested route; checks and recorded completion advance sequentially, but out-of-order Parts remain readable. Wrong answers retain every control, consume no life, and never remove access.
- Each Part keeps its optional mythic mnemonic visibly separate from every micro-lesson's factual claim, source and observation dates, uncertainty, material limitations, risk context, and knowledge check.
- Every Invest micro-lesson starts a best-effort English read-aloud when opened. A shared Mute/Unmute preference remains in effect while the member moves between lessons; leaving, advancing, opening Rowan, or backgrounding stops the current narration. Browser autoplay policy or missing speech support may prevent playback, so replay remains available and written content stays primary. The implementation uses the system voice available on the member's device or browser and never implies a fixed GPT or cloud-neural voice.
- Risk examples teach vocabulary and planning limits, not universal rules. Starpath never supplies a universal position size, a universal stop percentage (including 25%), an outcome probability, or a guaranteed return; `1:3` is a plan ratio, not a promise or forecast.
- Rowan may reveal only the deterministic, reviewed explanation pinned to that lesson revision. There is no free-form Starpath prompt, recommendation, prediction, or progress mutation through Rowan.
- Starpath does not read holdings, balances, orders, investor-profile answers, astrology profile, security preferences, or inferred intent. Its primary measurement is an aggregate return-to-learning definition, `learning_retention_within_7d_v1`; it has no product target until the product owner sets one after a real baseline exists.
- Legal counsel approves the versioned no-advice policy before production publication and again when a defined expansion trigger changes the risk boundary. Routine factual lesson revisions receive distinct factual and compliance review rather than individual legal approval.

## Discover AI Analysis Product Contract

- Discover may expose an optional AI Analysis entry and detail with visible hypothetical, simulation, and filing-reconstruction labels. The overview separates `Leo Models`, `AI Model Experiments`, and `Public Filing Reconstructions`; statuses with different methods or dates are never blended into one unlabeled ranking.
- Third-party model names may identify an independent Leo interface experiment only when the copy says it is an unofficial historical simulation, not an official model output, immutable forward test, provider-endorsed product, or proof of model skill. Model-provider logos remain absent without rights clearance. A company brand mark may identify a displayed holding only when it is available through the vetted icon library, used nominatively at avatar scale, and accompanied by Leo's visible no-affiliation/no-endorsement context; unsupported symbols use a neutral ticker fallback. Package inclusion does not replace trademark and brand-guideline review before production release.
- Manager reconstructions pair the filing entity with its associated public figure in a compact Smart Money card. A locally bundled portrait may appear only with a documented reusable license and visible non-affiliation context; it identifies the person and never implies endorsement. A 13F reconstruction identifies the report and filing dates, starts any hypothetical follower result only after public filing, excludes unsupported option rows, and states that delayed filings omit shorts, cash, and many other assets. It never reports a manager's or fund's actual return.
- Every model record identifies its track-record status as `live`, `paper forward test`, or `backtest` and keeps the exact evaluation dates, same-period benchmark, maximum drawdown, holdings-as-of date, model and methodology versions, and material assumptions adjacent and inspectable. Backtests and paper results remain explicitly hypothetical rather than blended with live performance.
- Each profile detail may provide a dated return chart, holdings, sector allocation, and a fixed-amount historical replay. The replay applies the displayed historical return to an example amount; it is neither a future-value projection nor an order action.
- Strategy illustrations and holding avatars are identification aids, not recommendations, sponsorships, or claims of affiliation. Their accessible labels name the model or holding, and meaning never depends on the logo or brand color alone.
- Market Risk reports a timestamped pressure regime and the indicators behind it. It is not a bear-market forecast, crash probability, sell signal, or instruction to change exposure.
- The snapshot is time-sensitive, uncached, and fail-closed. An expired, not-yet-available, or failed fetch shows AI Analysis as unavailable rather than restoring stale returns, holdings, or risk state.
- AI Analysis is general research education, not a personalized recommendation. It does not read brokerage state, infer suitability, rank securities for a member, place orders, or promise future performance.

## Accessibility & Inclusion

Target WCAG 2.2 AA contrast and semantics while respecting iOS Dynamic Type, Android font scaling, VoiceOver, TalkBack, reduced-motion settings, platform back gestures, safe areas, and minimum 44pt iOS / 48dp Android touch targets. Information, authority, freshness, and risk must never rely on color alone. Astrology personalization remains optional, and tarot remains fully usable without birth details.
