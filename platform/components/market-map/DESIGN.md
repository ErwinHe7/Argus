# Market Map component contract

This document describes the implemented `MarketMap.tsx` and
`MarketMap.module.css` feature. It does not replace Leo's global product or
design guidance.

## Composition and visual language

Market Map is a research page centered on one chart. Leo's existing lion mark,
serif identity, dark aubergine surfaces, and restrained gold accents carry through
the page. The title, asset and last close precede the chart; supporting indicators,
the level ledger, and The Read follow in that order.

| Role | Value | Use |
| --- | --- | --- |
| Aubergine background | `#0d0912` | Page background |
| Raised aubergine | `#15101d` | Chart folio and research surface |
| Main ink | `#f6ecf7` | Titles and primary text |
| Secondary ink | `#c5b5ce` | Supporting text |
| Quiet ink | `#ad9ab7` | Labels, dates, and metadata |
| Gold | `#ecb667` | Last close, confirmed pivots, focus, and Leo accents |
| Lilac | `#d9a4df` | SMA, Bollinger bands, base scenario, and evidence actions |
| Sage green | `#91c7af` | Rising candles, support, and upper scenario marks |
| Coral | `#ef9c98` | Falling candles, resistance, and lower scenario marks |
| Divider | `#372a40` | Grid lines and section boundaries |

Instrument Serif presents the Leo wordmark and editorial headings. Inter presents
controls, research copy, labels, and tabular numbers. The chart folio has a thin
border and moderate corner radius; lower sections use spacing and dividers.

At desktop width the page uses a centered, generous content area, with a full-width
chart, four supporting indicator panels, and a two-column ledger/The Read section.
The scenario explanations follow in three columns. Sources and methodology are
available through a native disclosure panel.

## Chart and interaction

The chart displays the latest 100 returned daily bars. Its left field is labeled
`OBSERVED PRICE · DAILY`; the right field is labeled `CONDITIONAL SCENARIOS`,
followed by `TERMINAL CLOUD`. A vertical divider and faint lilac background separate
the simulation field from historical observations.

- Historical candlesticks, the SMA line, Bollinger envelope, and confirmed pivot
  markers use the engine's observations and features. Confirmed pivots have gold
  letter markers; the provisional leg is dashed.
- Gold marks the last close. The same six levels are shared by the chart and
  ledger: stretch, resistance, last, SMA20, support, and down.
- Dashed bull/base/bear reference paths and the particle cloud represent conditional
  historical-bootstrap simulations. They are labeled uncalibrated and not forecasts.
  Particle positions on the price axis come from the engine; horizontal jitter is
  only a display arrangement.
- `Bollinger bands` and `Simulation cloud` buttons toggle their respective chart
  layers. Hiding the cloud leaves the three scenario reference paths visible.
- `5D`, `10D`, `20D`, and `60D` select independently computed artifacts. Switching
  horizons updates the chart, supporting panels, ledger, and explanation together
  and clears the current evidence highlight. The illustrative page starts at 20D.
- Hovering or clicking historical candles selects an observation. The session
  inspector exposes exact open, high, low, and close values; its range control
  provides an alternative to chart pointing. Reset returns to the last session.

The supporting panels are volume, RSI14, momentum, and 30-day ATM IV. The sector
strip reports benchmark return, the asset's relative performance, and the engine's
backdrop label. Observed-trade volume by price is a separate section when that
input exists; it is not represented by simulation particles.

## Mobile behavior and accessibility

Below 700px the chart retains a minimum width of 850px inside its own horizontal
scroll region. It does not squeeze dense historical and projected marks into a
phone-width chart. The page initially scrolls the chart to the simulation side.
`Price history` and `Scenario cloud` buttons let users jump between the two sides;
horizontal touch scrolling remains available.

Horizon controls span the asset card width. The four panels become a two-by-two
grid; the sector strip, ledger, The Read, scenario explanations, and methodology
stack vertically. The page itself fits the viewport while the chart alone scrolls.

Controls expose names and pressed states. Keyboard users receive a gold visible
focus outline, a skip link to The Read, a focusable chart region, and the session
range control. The chart has an SVG title and description, and exact level values
remain available in a semantic table. Mobile evidence and horizon controls have
generous touch targets. Reduced-motion preferences remove transitions.

## The Read and source semantics

The Read renders the explanation supplied by the same validated snapshot as the
chart. It does not request a separate model opinion or derive new market facts in
the browser. Each `Show evidence` action reveals the referenced evidence labels
and dates and highlights corresponding levels or supporting panels. Ledger
selection uses the same evidence references.

The displayed price is the last completed daily close, not an intraday quote.
Levels describe price structure; they are not intrinsic-value estimates or order
instructions. Simulation paths remain conditional and uncalibrated. TypeScript
handles rendering, formatting, and interaction; the research/runtime layers own
quantitative calculations.

The sources disclosure exposes the observation cutoff, generation time, coverage,
model and methodology, trial count, assumptions, provider/dataset labels, stated
delays, and material caveats. IV is a historical ATM series with a consistent
tenor. Its observation can precede the same day's close; it is not relabeled as an
observation made at the close.

## Illustrative and market-data routes

`/discover/market-map/preview` is explicitly illustrative. It has a prominent
synthetic-input notice, the `DEMO` identity, `EXAMPLE SESSION` metadata, and a
synthetic-example footer. All four example artifacts pass the same serialization
contract, but they are accepted only through the separate illustrative mode.
The page is excluded from indexing.

`/discover/market-map/[symbol]` renders only authorized, complete, fresh production
artifacts for authenticated members with research access. Missing data produces
no market card; the production route never silently loads the example. A manual
`Refresh snapshot` control reloads the server snapshot. The component hides an
expired snapshot and rechecks expiry when the page becomes visible again. It
does not poll quotes every few seconds.

## Review provenance

The latest owner correction replaces the Taiwan universe with U.S. stocks and
ETFs, defaulting to AAPL. The public selector shows only instruments listed by
the active validated feed. The source strip uses USD and, for HF Data Library,
explicitly names IEX-only trade coverage. Footer attribution follows the actual
source, including HF/IEX terms only when HF supplied the observations. The
public route returns 404 with missing core data, and the homepage/navigation
entry appears only while a validated U.S. feed is available.

The U.S. local review used genuine EODHD demo observations for AAPL and a named
VTI benchmark. The page displayed AAPL 328.21 for September 3, 2026; changing
20D to 5D updated both the scenario field and The Read (median terminal price
339.97 to 332.85 in that specific input). Source terms explicitly limited this
feed to personal local evaluation. This check does not establish public HF
data activation, which still requires its free verified-account key.

The following paragraphs describe earlier releases and visual evidence.

The follow-up real-data release replaces the synthetic preview entry with
`/discover/market-map`, showing TWSE 2330 and 0050. The original preview URL now
redirects there. A compact source strip names the real exchange and lets users
switch assets. Option IV is absent in this source; the fourth panel is explicitly
labeled ATR14 in TWD and states that option IV is unavailable. All dates use the
asset's market timezone. The source attribution and open-data license appear in
the footer. The original illustrative and member contracts remain separate in
code, but the user-facing default no longer loads illustrative fixtures.

Real-data browser verification covered switching 2330 to 0050, switching the
simulation horizon, and linking explanation evidence. The 0050 page showed the
official 107.90 close and updated its simulation summary when switching to 5D.
The mobile source strip, asset names and selection controls fit the viewport.

The original reference image was unavailable in the supplied material. The page
was recreated from the provided component inventory and Leo's existing visual
world, rather than claimed as a pixel-identical reproduction.

Visual evidence is recorded in `.impeccable/review/desktop.png`,
`desktop-read.png`, `mobile.png`, and `mobile-cloud.png`. The final review reused
the existing review agent because the available agent/thread limit had been
reached. Its disposition was **Ship for the explicitly illustrative preview**.
That review disposition does not assert real-data or deployment readiness.
