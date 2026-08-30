# Product

## Register

product

## Platform

adaptive

## Users

Gen Z and millennial women who want investing to feel approachable without losing evidence, uncertainty, or control. They use Argus for short daily rituals, deeper research, and deliberate reviews of an existing Webull brokerage relationship.

## Product Purpose

Create an adaptive iOS, Android, and mobile-web investing companion where tarot and astrology make market research emotionally approachable while factual signals remain inspectable. The public web beta preserves the existing member experience against beta services; it does not make unfinished privacy or brokerage capabilities functional. Members may eventually connect an existing Webull account, understand timestamped brokerage state, and explicitly confirm only supported manual order actions after their separate launch gates pass. Argus is not a brokerage, does not open or fund accounts, and does not maintain a second brokerage ledger.

## Authority Model

- Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders.
- Argus is authoritative for ritual, editorial, community, preference, and privacy state, including Daily Ritual, discovery, Circle, Grimoire, Founders' Coven, Intentions, and Future Mirror scenarios.
- Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Flutter calls the versioned Argus API for application and brokerage data and uses Supabase directly only for Auth and approved Storage transport.
- The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated. It is a separate product surface, not a mode or ledger in the production member app.
- Cloudflare Pages continues to serve the unchanged static landing and standalone Demo assets. Cloudflare Workers Static Assets may deliver the compiled member web beta at the apex, but Cloudflare receives no Auth, application-data, database, provider, or stateful backend authority.
- The member web beta is invite-first and uses only the beta Supabase Auth and versioned beta Argus API boundaries. Self-service signup remains unavailable pending its separate evidence gate.
- Current member behavior is preserved. Unfinished privacy actions and every brokerage read or mutation are visibly unavailable and fail closed; the standalone Demo is the only synthetic experience and is always an explicit handoff.

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
- Demonstrate honestly: synthetic state exists only in the standalone Demo and remains visibly marked Demo.

## Accessibility & Inclusion

Target WCAG 2.2 AA contrast and semantics while respecting iOS Dynamic Type, Android font scaling, VoiceOver, TalkBack, reduced-motion settings, platform back gestures, safe areas, and minimum 44pt iOS / 48dp Android touch targets. Information, authority, freshness, and risk must never rely on color alone. Astrology personalization remains optional, and tarot remains fully usable without birth details.
