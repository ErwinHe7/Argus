# AXIO7 30-day user-acquisition operating plan

## Outcome and audience

The near-term objective is not raw traffic. It is more qualified users who
reach one evidence-backed research result and understand why its data and
validation receipts are trustworthy.

The initial audience is self-directed US-equity researchers, active traders,
and quant-curious investors who already compare sectors or themes and are
frustrated by unsupported market narratives. AXIO7 remains impersonal market
research: no personalized recommendation, order placement, or risk-free claim.

## Funnel and measurement

The production funnel is:

1. `acquisition_landing_viewed`
2. `starter_selected`
3. `sign_in_started`
4. `user_signed_up`
5. `pricing_cta_clicked`
6. `checkout_started`
7. `checkout_completed`
8. `research_submitted`
9. `research_completed` or `research_failed`

First-touch UTM values, referrer host, and landing path are bounded and
allow-listed. No email address, auth code, complete URL query, market-data
credential, or research question is captured in acquisition properties.

The primary activation metric is a first completed research result. The first
weekly baseline must be measured before targets are treated as commitments.
Initial experiment targets are directional thresholds, not claims about
current performance:

- at least 20% of qualified landing sessions select a starter;
- at least 30% of starter selections begin sign-in;
- at least 70% of submitted research requests complete;
- no paid channel is scaled until activation can be attributed end to end.

## Week-by-week sequence

### Days 1-3: repair trust and activation

- Publish the public, read-only runtime probe so a healthy engine is never
  shown as offline merely because the visitor is signed out.
- Make guest starter prompts actionable and route them through the measured
  sign-in/pricing path.
- Ship the sector-rotation methodology page with explicit provider, cutoff,
  availability, coverage, validation, and caveat requirements.
- Verify the funnel in PostHog using internal test traffic marked with
  `utm_source=internal` and exclude it from acquisition reporting.

### Days 4-10: founder-led distribution

- Prepare one short screen recording that starts with a real user question,
  shows the evidence receipt, and ends at the membership choice.
- Create a Product Hunt draft only after the production experience is usable.
  Use the product URL, at least two gallery images, a concise tagline, honest
  pricing, maker identity, and a first comment that asks for feedback.
- Publish three founder posts: the false-offline lesson, why sector rotation
  needs point-in-time data, and how walk-forward validation differs from a
  backtest screenshot. Each post uses a distinct UTM content value.
- Engage in relevant communities with educational analysis first. Check each
  community's rules and ask moderators when self-promotion is ambiguous. Do
  not automate posts, mass-message users, or ask for coordinated votes.

### Days 11-20: search and referral loop

- Expand only from questions users actually submit: cloud leadership,
  semiconductor leadership, software leadership, Mag-7 breadth, and
  defensive rotation. Each page must add original methodology or evidence;
  do not mass-generate near-duplicate pages.
- Add a share action for a sanitized research receipt only after it is proven
  not to expose entitlements, tokens, personal data, or unpublished values.
- Ask activated users one question: “What decision did this report help you
  research?” Tag the answer by job-to-be-done, not by portfolio identity.

### Days 21-30: double down or stop

- Compare cohorts by source through activation and paid conversion, not clicks.
- Keep channels whose activated-user rate beats the measured organic baseline.
- Rewrite or stop any page/channel that brings traffic but no starter
  selections after a statistically useful sample.
- Consider paid acquisition only after a complete attribution path, a stable
  research-completion rate, and a known maximum acceptable acquisition cost.

## Launch copy kit

Tagline:

> Evidence-backed market research with point-in-time data and walk-forward validation.

Short description:

> AXIO7 helps you examine sector leadership, historical analogs, and market
> conditions without inventing missing data. Every result exposes its source,
> cutoff, freshness, coverage, model version, and caveats. Research only; no
> order execution or personalized advice.

Founder post hook:

> “Which sector is leading today?” sounds simple. It is not. Cloud, software,
> semiconductors, Mag 7, and broad sectors can disagree—and a backtest can
> accidentally use data that was not yet available. We built AXIO7 to make the
> cutoff, coverage, and validation visible.

## Campaign naming

Use lowercase, stable identifiers:

- `utm_source=producthunt&utm_medium=launch&utm_campaign=sector_rotation_v1`
- `utm_source=x&utm_medium=founder_post&utm_campaign=sector_rotation_v1`
- `utm_source=linkedin&utm_medium=founder_post&utm_campaign=sector_rotation_v1`
- `utm_source=reddit&utm_medium=community&utm_campaign=sector_rotation_v1`

Set `utm_content` to the specific creative or post theme. Never reuse a UTM
for unrelated content and never put user identity or a research question in a
UTM value.

## Release gate

No launch is scheduled until production shows the public engine as connected,
sign-in and Paddle checkout are verified, an authenticated research request
completes, automatic execution remains disabled, and rollback evidence exists.
