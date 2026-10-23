---
name: Astra's Pick
description: A concise research workspace with aubergine surfaces, candle-gold actions, and Leo's Lion identity.
colors:
  candle-gold: "#ecb667"
  gold-hover: "#f6c782"
  lilac: "#d9a4df"
  observed-green: "#a3d2ba"
  loss-red: "#f0a8a1"
  aubergine: "#0d0912"
  panel: "#17101f"
  rule: "#382a43"
  ink: "#f6edf7"
  muted: "#bfafca"
  field: "#130d1c"
  field-rule: "#594463"
  action-ink: "#261c17"
typography:
  display:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "clamp(34px, 3.1vw, 48px)"
    fontWeight: 750
    lineHeight: 1.15
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "40px"
    fontWeight: 800
    letterSpacing: "-0.035em"
  section:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "18px"
    fontWeight: 650
    letterSpacing: "-0.02em"
  title:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "23px"
    fontWeight: 700
    letterSpacing: "-0.025em"
  body:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.7
  label:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "13px"
    fontWeight: 400
rounded:
  square: "0px"
  field: "4px"
  option-panel: "12px"
spacing:
  compact: "8px"
  control: "12px"
  inset: "16px"
  mobile-gutter: "18px"
  tablet-gutter: "24px"
  workspace-gap: "28px"
components:
  button-primary:
    backgroundColor: "{colors.candle-gold}"
    textColor: "{colors.action-ink}"
    rounded: "{rounded.square}"
    padding: "11px 16px"
  button-primary-hover:
    backgroundColor: "{colors.gold-hover}"
  button-border:
    backgroundColor: "#21172b"
    textColor: "{colors.ink}"
    rounded: "{rounded.square}"
    padding: "11px 16px"
  button-text:
    textColor: "{colors.candle-gold}"
    padding: "11px 0"
  input:
    backgroundColor: "{colors.field}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "10px 12px"
  navigation:
    textColor: "{colors.muted}"
    padding: "10px 12px"
  chip:
    textColor: "{colors.muted}"
    rounded: "{rounded.square}"
    padding: "5px 8px"
  chart-readout:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    rounded: "{rounded.square}"
    padding: "22px 25px"
  iv-matrix-cell:
    rounded: "{rounded.field}"
    width: "100%"
---

# Design System: Astra's Pick

## Overview

**Creative North Star: "Aubergine market analyzer"**

Astra's Pick presents research in a clear reading order: a candidate, the reason it deserves attention, supporting evidence, and a next action. Deep aubergine surfaces, candle-gold controls, lilac evidence, and the retained Leo Lion extend the existing model interface. Short English copy, readable rows, and practical controls carry the workspace.

This design owns the root research workspace, its tools, and Options lab while embedded here. Internal source and asset paths retain research-desk naming for compatibility. The original site at /original/, the Leo app at /app/, and global PRODUCT.md and DESIGN.md remain separate. The [surface brief](.impeccable/surfaces/desk-tsx.md) records the current Picks-first composition, which supersedes the former selector-first home within this existing visual world.

**Key Characteristics:**
- Aubergine surfaces and fine structural rules.
- Clear rows and progressive disclosure of supporting evidence.
- Candle-gold actions, lilac evidence, and compact Inter text.
- Descriptive observations, conditional valuations, and personal plans have distinct labels.

Sources: [AstraHome.tsx](AstraHome.tsx), [shortlist.css](shortlist/shortlist.css), [publication.ts](shortlist/publication.ts), [ExploreMarkets.tsx](ExploreMarkets.tsx), [ExploreMarkets.css](ExploreMarkets.css), [Desk.tsx](Desk.tsx), [CryptoMarkets.tsx](CryptoMarkets.tsx), [desk.css](desk.css), [catalog.ts](catalog.ts), the shared [TradingView presentation](tradingview/TradingView.tsx), and [IvLab.module.css](../../components/iv-lab/IvLab.module.css). This record describes the current local implementation. Review evidence and release status remain separate from design authority.

## Colors

The user requested the existing model's purple background. Aubergine, purple panel, and plum rules provide the working field; warm gold marks actions and selection.

- **Primary — Candle gold:** planning and analysis actions, selected candidate identity, active filters, and task links. Gold hover lightens primary controls.
- **Secondary — Lilac:** the longer moving average and IV percentile emphasis. Observed green and loss red distinguish signed observations and conditional outcomes; the options matrix keeps its own red/green scale. The automatic-screening line also uses observed green for a recent, available waiting publisher and gold for its inactive states, always accompanied by explicit words.
- **Neutral — Aubergine, panel, rule, ink, and muted:** background, restrained containers, divisions, principal text, and supporting context. Field and field-rule identify editable controls.

**The Evidence Color Rule.** Color reinforces a signed value, selection, or action; it never establishes the probability of a market outcome.

## Typography

The existing variable Inter font is self-hosted as DeskInter with swap loading. The opening heading is heavy and close-set, the body is brief, and instrument names and figures carry the working hierarchy. The Picks introduction uses 15px text; working explanations generally use 13px to 14px. Candidate symbols use 26px text at weight 650, with 17px recorded prices and 12px company names. Ranks, recorded prices, tables, and Options lab use tabular numerals.

The frontmatter records active desktop roles. The Picks heading becomes 36px at 800px and below, then 32px at 380px and below; its leading remains 1.15. Candidate symbols become 25px on mobile, while reasons retain 14px text. Tool page titles become 32px at 700px and below. Labels identify instruments, sources, dates, fields, and states. The by-Leo line is brand attribution.

The opening candidate answer uses a 22px semibold heading with 1.4 leading, becoming 21px at the shortlist's mobile breakpoint. Its explanation uses 13px text, 1.7 leading, and a 75ch bound. The automatic-screening line uses 12px text with a medium-weight state label. These are scoped component treatments within the existing Inter hierarchy.

**The One Reading Voice Rule.** Use concise English labels and the existing Inter family for Leo-owned analyzer and embedded Options lab controls. TradingView's isolated presentation retains its own typography and attribution.

**The Semantic Label Rule.** Give small labels a concrete job; do not add promotional overlines above headings.

## Layout

Picks centers within a 1600px maximum width. A short introduction and automatic-screening status lead into asset-type filters and the snapshot date, then a plain candidate answer, scope line, ranked rows, and supporting detail. The answer places its Why action alongside the text on desktop; at 800px and below the action sits beneath the explanation and the status detail takes a separate line. The desktop list/detail grid uses equal columns with a 44px gap; at 1100px it becomes .95fr / 1fr with a 28px gap. Horizontal gutters are 3.5%, then 24px at 1100px and 18px at 800px. At 800px and below, the complete shortlist precedes the selected detail. Explicit selection moves focus to the detail heading; Back to shortlist returns focus to the selected row. Initial loading does not move focus away from the opening list. The detailed home composition belongs to the surface brief, not every tool page.

The primary navigation is Picks, Markets, My plans, and Tools. Tools discloses the twelve supporting routes; existing hash routes remain compatible. At 1100px navigation wraps into a second row; at 700px the toggle opens a two-column menu and Tools expands within it. A provider tape appears only on Charts, Market overview, Technology, Crypto, and Options lab. Picks, Markets, Strategies, and the dedicated authentication callback mount no tape. When reduced motion is requested on a tape-bearing route, Leo replaces the hosted tape with ten static symbol links and a market link; the strip displays no prices and mounts no tape frame.

Tool bodies center within a 1600px maximum. Markets uses stock, crypto, and forex tabs above the provider screener, with source and coverage context outside the hosted stage. Screeners reserve 640px on desktop and 600px at 700px and below. The compact candidate chart reserves 370px, becoming 350px at 700px and below; full chart stages reserve 560px, becoming 480px at that breakpoint. These chart dimensions are independent of the shortlist's 800px stacking breakpoint. Provider controls and attribution remain visible when the provider renders them.

Embedded Options lab uses its actual div wrapper with 28px / 3.5% padding, becoming 24px / 16px at 700px. Its watchlist becomes horizontal at 900px and three columns at 650px. Within each mobile cell, symbol, IV, and percentile stack on separate rows; the scenario outcome moves below the matrix. Detailed recorded stock charts retain accessible horizontal scrolling. Crypto uses the shared full TradingView chart stage.

**The Workspace Gutter Rule.** Preserve outer space around the options snapshot, watchlist, matrix, and outcome. Embedded mode removes the standalone header, introductory title and copy, and footer while preserving the snapshot date and status.

## Elevation & Depth

The Leo-owned analyzer uses no box shadows. Surface tone, one-pixel rules, and selected outlines establish depth. Primary charts use the provider's dark candle-and-volume plot; recorded research charts retain their lines and light area fills inside the archive disclosure. Options controls transition background and text color over 160ms; reduced-motion preferences disable transitions. Historical replay starts only after the user selects it.

**The Flat Surface Rule.** Build hierarchy with tone, rules, type, and selection rather than decorative elevation.

## Shapes

Primary actions, navigation, shortlist rows, chart containers, and readouts use square forms. Fine horizontal rules separate candidates; selection adds panel tone and gold identity. Inputs have small corners; the retained Lion has a 5px corner. Embedded Options lab keeps its existing 12px panel and watchlist corners, with 4px button corners in this context.

## Components

- **Automatic-screening status:** a compact status line uses the existing muted body, gold inactive state, and green active state. Its words distinguish saved evidence, interrupted updates, invalid input, paused publication, stopped publication, and an available recent publisher. Publisher activity does not change the source date or establish a fresh market observation. The visible page polls the validated publication envelope every 60 seconds and refreshes when made visible; requests do not overlap.
- **Opening candidate answer:** the first row in the selected group supplies the named starting point and plain reason. All-checks, incomplete-checks, and expired-ranking cases have distinct copy. Why followed by the symbol selects that candidate and scrolls to supporting detail; mobile selection also focuses the detail heading. The answer reuses the flat surface, existing text action, and direct movement without adding animation.
- **Candidate rows and detail:** a full-width button carries rank, symbol, recorded close, company name, plain-language reason, and criteria count. Gold symbol/rank and panel tone identify selection; aria-pressed and visible focus convey it without color alone. Supporting detail holds the chart, published checks, counterpoint, what to review, dated coverage, and a symbol-preserving plan action. Standard primary actions retain a 44px minimum height.
- **Filters and disclosure:** Stocks and ETFs & funds use labeled pressed-state buttons with a gold underline. Compare all expands the tracked group; How we choose opens and focuses its native disclosure. Dates and universe scope remain above the rows. The three-check count is a descriptive screen result, not a probability or forecast.
- **Navigation:** Picks, Markets, My plans, and Tools expose the homepage and fourteen catalog routes. Original Leo opens /original/ and the footer's Leo app link opens the preserved app. Mobile state, the Tools disclosure, and the skip link remain keyboard accessible.
- **Markets:** Stocks, Crypto, and Forex are keyboard-operated tabs, with Arrow keys, Home, and End moving both selection and focus. Only the active tab mounts a screener. The full-screener link follows the active market. Provider ordering, ratings, coverage, and delays remain clearly separate from Astra's small dated research universe. Recorded observations and export remain in their own disclosure.
- **Chart and reading:** official TradingView candles and volume support the selected candidate, Charts, Market overview, Technology, Crypto, and the embedded Options Charts tab. U.S. widgets may be delayed. Dated research and its Python-generated descriptions remain clearly labeled. Historical indicators, replay, and exports remain available in disclosures. What-to-watch text compares against frozen reference levels, not alerts or targets.
- **Options matrix:** signed red/green cells and a gold selected outline connect stated price, IV, and time assumptions to a theoretical result. Units, premium basis, attribution, exclusions, and the save-note action remain visible or available in methods.
- **Crypto chart:** BTC and ETH controls select TradingView's Coinbase USD daily chart. TradingView credit and UTC context remain visible. The chart is externally hosted; it supplies no local crypto dataset or stock-options inputs. Create a plan carries BTC-USD or ETH-USD into the local form.
- **Provider recovery:** a reserved chart stage prevents layout collapse while loading. Chart Retry and the external TradingView link remain available in every chart presentation state, including after the provider embeds. Other widgets show Retry after a detected failure. Unknown listings show a symbol-search link instead of a guessed exchange. A loaded frame or embedded message establishes presentation only; it does not establish valid, available, fresh, or entitled quotes. A blank chart is an unresolved provider presentation state, not an approved empty-state design.
- **Shortlist states:** loading and initial failure show explicit messages. Invalid or future evidence is rejected. If the published feed is unavailable, the client can show a validated saved snapshot and labels automatic updates disconnected. Existing data is retained when a feed response would move the snapshot date or retrieval time backward; publisher heartbeats also do not move backward. When both refresh sources fail, the previous dated list remains with an alert. An expired review deadline labels the retained ranking historical, including the opening answer. Empty groups explain the absence of usable evidence. Download the ranked evidence serializes the shortlist currently displayed, including its dates and limitations. Missing values receive no invented replacement.
- **Records and states:** trade plans and notes identify their local storage, dates, review, and export controls. Missing data stays missing. Errors name recovery. Gold focus uses a 2px outline with a 4px offset, or 3px inside Options lab; disabled controls visibly reduce opacity.

## Do's and Don'ts

- Do use Astra's Pick as the public name and retain Leo's existing Lion and Inter assets with provenance.
- Do make candidate reasons, supporting evidence, broader markets, and plan creation easy to find.
- Do show dates, units, sources, and conditional assumptions beside their evidence.
- Do retain keyboard focus, responsive menus, reduced-motion handling, and deliberate data scrolling.
- Do preserve THESIS, OWN-WORLD, STORY, FIRST VIEWPORT, FORM, and FINISH in the source and emitted HTML's first body comment.
- Don't restore the superseded selector-first home, promotional hero, count strip, or home tool grid during refinement; this is the current homepage contract, not a ban on selectors in supporting tools.
- Don't relabel archived stocks as live, descriptive trend states as probabilities, or conditional option values as forecasts.
- Don't present hosted TradingView charts as a raw data feed for local research, option calculations, or execution. Provider scripts run inside opaque data-origin frames, never the parent authentication origin. Private Strategies and its callback mount no widgets. The provider's own dark chart, Arial attribution fallback, and link blue remain isolated provider presentation, not Leo brand tokens.
- Don't transfer this scoped design into the preserved original site or Leo app.

Assets: [Lion provenance](../../public/app/research-desk/lion.png.json) and [asset manifest](../../public/app/research-desk/asset-provenance.json). Both retain the existing asset sources; no new image generation is claimed.

Current refinement evidence: the [automatic Picks browser receipt](../../.impeccable/review/automated-picks/browser-checks.json) records six passing local checks and no page errors. The independent [finish review](../../.impeccable/review/automated-picks/finish-review.md) gives a scoped ship disposition for the automatic-feed status, lead answer, retained list/detail hierarchy, claims, focus, and mobile presentation. Its three valid captures are desktop and mobile opening viewports plus the selected mobile detail; they are not full-page captures. No detector ran for this refinement, and earlier detector results do not validate it. The homepage and feed are now deployed; the separate live-verification receipt records advancing publication heartbeats and preserved source dates. This local review establishes neither the full hosted workflow nor provider quote accuracy. Current release status belongs to the delivery records.

Preceding Picks evidence: `../../.impeccable/review/picks/` records fourteen passing functional browser checks and a valid targeted default-mobile-chart recapture. Its [finish review](../../.impeccable/review/picks/finish-review.md) inspected the default NVDA chart, real 390×844 viewport, and [capture-method receipt](../../.impeccable/review/picks/mobile-chart-recapture.json). The initial request remains in [recapture-review.md](../../.impeccable/review/picks/recapture-review.md). That full-page evidence used temporary viewport-height expansion at unchanged mobile width without editing page content, data, CSS, ticker, or image pixels. It does not establish coverage of the later automatic-feed refinement. Earlier Astra and TradingView review/release receipts remain historical evidence in the surface brief and sidecar. A generic agent performed this merge using Impeccable's documenter role; no new visual world, comp, or raster asset was created.

## Event radar · September 10, 2026

The current main navigation is Picks, Radar, Markets, My plans and Tools. Radar
extends the incumbent flat aubergine/gold system. Its desktop calendar/detail
columns have a 50px gap (28px at 1100px); at 800px they stack. A 44px maximum
Inter headline leads into compact source status, filters, search and ruled event
rows. Verified exact timestamps determine the displayed day, order and plan date.
A mobile selection focuses the detail heading without scrolling it separately;
the entire detail container scrolls into view so Back to calendar remains visible.

The evidence assistant sits below the selected event. Supported questions return
short sourced paragraphs; changing the evidence or source-freshness state clears
old answers. A report import disclosure follows it, then source coverage and the
research record. Sources and dates carry the evidence hierarchy; no confidence
meter or invented win rate is used. The homepage remains shortlist-first and
adds one compact Next catalyst link below the research list. Existing rasters
and TradingView attribution are unchanged; no new bitmap asset was generated.

## Google welcome and account · September 11, 2026

`/#/welcome` is a supporting account page within the existing Leo visual system;
Picks remains the public opening route. The header adds a 44px account control,
with an accessible icon label when its text hides on smaller screens. The welcome
layout pairs a concise research introduction with one account panel, bounded to
1160px. At 700px it becomes one column with 18px gutters. Signed-in, restoring,
unavailable and recoverable-error states use the same space without adding another
navigation hierarchy. Private strategy evidence clears when identity changes.

Leo-owned text retains Inter, aubergine surfaces, fine plum rules and candle-gold
research links. The Google action is the unmodified official light square PNG,
displayed at 216×48 with preserved aspect ratio; its G colors and Google Sans are
provider branding rather than new Leo tokens. [Provenance](account/google-signin.png.json)
records the original asset. Sign-in and its callback mount no TradingView frames,
and archive loading cannot block the account interface.

The [auth runbook](../../../docs/google-sign-in.md) records the PKCE boundary,
membership requirements and publication evidence. Nine fixture browser groups and
five existing strategy groups passed; desktop 1536×960, mobile 390×844 and
signed-in/error captures are in `../../.impeccable/review/account-auth/`. These
captures show layout and injected states, not a completed hosted Google login.

## Model atlas · October 22, 2026

The Model atlas is a supporting read-only extension of the existing research
workspace. Its nine frozen candidate selectors retain aubergine panels,
candle-gold selection, lilac chart geometry, Inter, fine rules, and the Leo Lion
identity. At 1200px and above the picker has nine columns; at 700px and below it
has three. The pipeline stays in a native disclosure. A selected regime links
the volatility/drift chart, readout, and regime table; transitions and state-count
selection follow before kernel settings and lineage. Tables keep deliberate
horizontal scrolling within their own labeled, keyboard-focusable regions.

The bounded finish review initially required two accessibility fixes: a native
Candidate scores table for the score chart, and a Full artifact identifiers
disclosure with selectable, wrap-safe hashes, commit, and artifact path. Both
are implemented and the final review verdict is **ship** for the rendered regime
views and these two fixes. Browser checks at 1280px and 390px found no page
overflow or runtime errors and exercised keyboard regime selection and switching
from a 12-regime model to an 11-regime model. The [surface review](models/SURFACE.md)
links the captures and records the limited scope. No new raster assets or design
tokens were introduced.

## Quant practice · October 22, 2026

`/#/learn` adds a supporting chapter companion in the incumbent aubergine,
candle-gold, lilac, Inter, and fine-rule system. A compact title and progress line
lead into a desktop chapter rail and working activity; at 760px and below, a
labelled native select replaces the rail. All seven chapters remain open. Each
has a playable lab, followed by original exercises, hints, worked explanations,
and review. Labs are untimed. The optional 90-second practice clock starts
enabled but waits for an explicit start and permits continued solving at expiry.

The 58 exercises use offline-computed references and fictional lab fixtures.
Misses and help-assisted answers remain in review until a later independent
pass. Progress is browser-local, separate from identity, with export/import
merge and an explicit clear confirmation. Native controls, visible focus, status
feedback, diagram descriptions, and native probability/payoff tables support the
learning flow. Completion records activity rather than certified mastery.

The bounded independent finish verdict is **ship**, with no material findings
for the inspected source and captured states. The [surface record](../quant-practice/SURFACE.md)
records the implementation owner's Python, TypeScript, build, and browser checks,
the zero-finding mechanical detector, and all five evidence filenames with their
actual dimensions. Requested 1280×900 and 390×844 DOM width checks found no page
overflow; the captures are cropped viewport evidence, not full-page proof.
The reviewer did not independently attest browser execution, numeric validation,
or deployment. Shared tokens, existing sidecar authority, and shipping rasters
remain unchanged; release status belongs to the delivery receipts.
