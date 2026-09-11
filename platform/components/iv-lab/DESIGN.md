---
name: Leo IV Lab
description: Scoped design contract for the English options research workbench.
colors:
  aubergine-bg: "#0d0912"
  aubergine-panel: "#17101f"
  aubergine-hover: "#241a2e"
  divider: "#382a43"
  ink: "#f6edf7"
  muted: "#bfafca"
  quiet: "#aa96b7"
  candle-gold: "#ecb667"
  evidence-lilac: "#d9a4df"
  gain-sage: "#a3d2ba"
  loss-coral: "#f0a8a1"
typography:
  body:
    fontFamily: "var(--font-inter), 'Microsoft YaHei', sans-serif"
    fontSize: "14px"
    lineHeight: 1.6
  headline:
    fontSize: "30px"
    fontWeight: 600
    letterSpacing: "-.025em"
rounded:
  panel: "12px"
  control: "6px"
  matrix-cell: "5px"
spacing:
  small: "8px"
  medium: "16px"
  section: "24px"
---

# Design System: Leo IV Lab

## Overview

This contract applies only to `components/iv-lab` and the `/research/iv` surface. It extends the aubergine and candle-gold research identity in [MarketMap.module.css](../market-map/MarketMap.module.css); it does not redefine the global Leo brand. [IvLab.tsx](IvLab.tsx) and [IvLab.module.css](IvLab.module.css) are the implementation sources.

The surface serves an operating workflow: select an observed asset, state a theoretical option and time horizon, inspect a price × IV scenario, consult technical and event evidence, then save a testable hypothesis. English explanatory copy accompanies conventional tickers and option terms. The workbench must remain dense enough for comparison while keeping assumptions and evidence boundaries visible.

## Colors

Candle gold marks selection, focus, the reference price, and the primary save action. Lilac identifies evidence links and the chart's SMA20 line. Aubergine tonal steps and muted dividers organize the workspace; ink, muted, and quiet text form the reading hierarchy.

Sage and coral encode theoretical gains and losses. The matrix uses darker, stepped versions of these hues to distinguish magnitude, with a neutral center. Signed numeric values, explicit axis labels, and a gold selection outline carry meaning alongside color. These tones do not express a recommendation, likelihood, or confidence score.

## Typography

Use the incumbent Inter variable with Microsoft YaHei and sans-serif fallbacks for research content. Preserve the Instrument Serif/Georgia Leo wordmark; do not introduce a new display family. All financial numerals use tabular figures.

The page heading is compact and semibold; asset and price text sit below it in scale, followed by section headings and controls. The selected result is the largest numeric readout (38px on desktop, 34px on mobile). Supporting evidence uses generous line spacing (roughly 1.8–1.9) despite its compact size. Desktop labels generally use 10–12px. Keep English labels legible and units close to values.

## Layout

The desktop main container is centered with a maximum width of 1512px and 40px side padding. A sticky 235px watchlist sits beside the flexible research area, separated by a 28px gap. The research hierarchy is asset context → four tabs → assumptions → matrix and selected outcome → presets and Greeks. Methodology and provenance follow in a native disclosure.

The assumptions form uses four columns. The result sits in a 235px column next to the matrix and is separated by a vertical rule. Section spacing is generally 20–28px; inner controls and supporting text use smaller gaps. Preserve this relationship instead of adding dashboard tiles for every metric.

- At 1150px, reduce outer padding and sidebar/result widths to protect the matrix.
- At 900px, move the watchlist above the research area as six columns and remove sticky positioning. Compact navigation and supporting sidebar material; retain its evidence in the technical view.
- At 650px, use 16px page gutters, a three-column/two-row watchlist, wrapped asset metrics, and a two-column assumptions form. Stack the result below the matrix, with the headline result and scenario terms side by side. Evidence, methodology, and editor actions become vertical; metrics use two columns.
- The matrix retains all scenario columns with legible, selectable cells. Contract tables scroll locally at a minimum width of 650px.
- The mobile technical SVG retains a minimum width of 860px inside a focusable horizontal scroll region. Initially show the latest observations and right-hand price scale, including after changing symbols. Keep the historical range control outside that viewport. Never shrink the entire chart to fit a phone at the expense of its ticks.

## Elevation & Depth

Depth comes from darker and lighter aubergine surfaces, thin borders, and selected fills. There are no structural drop shadows. Keep hover changes restrained; the existing color transitions last 160ms. Respect reduced-motion preferences, including when scrolling the research editor into view.

## Shapes

Panels and grouped lists have gently rounded corners. Smaller radii distinguish controls and matrix cells; the theoretical-contract label is a compact pill. Thin rules divide instruments, tabs, outcomes, and methodology. Empty states use a dashed border. Preserve the flat, precise research-tool character.

## Components

- **Watchlist and tabs:** Asset buttons expose their selected state with `aria-pressed`. Tabs use linked tab/panel semantics, a gold underline, and roving focus with Left/Right, Home, and End keys. The four views remain scenario, technical/events, actual contract snapshots, and research notes.
- **Assumptions and matrix:** Native labeled selects and a Call/Put button group precede the result. Table headers explicitly distinguish stock-price percent changes from IV changes in percentage points. Each cell names its assumptions and theoretical P&L for assistive technology. Invalid IV cells display an em dash and are disabled. The selected outcome announces updates politely and atomically.
- **Financial semantics:** P&L percentages are relative to the initial theoretical premium. Dollar results distinguish per-share values from the assumed 100-share contract. Vega is per IV percentage point per share; theta is per calendar day per share. Greeks describe local sensitivity; the matrix uses repricing. The attribution includes the nonlinear residual. Keep the Black–Scholes assumptions and exclusions accessible.
- **Technical chart and evidence:** Show completed daily observations, close, SMA20, and Bollinger bands, with a textual inspected-date/close/RSI readout and a labeled range input. The chart has an accessible description and the scroll region has a visible keyboard focus ring. Technical indicators describe observations, not validated prediction probabilities.
- **Data provenance:** Identify archived snapshots as non-live, distinguish last-trade time from completed daily bars, and display ET where applicable. Aggregate IV is a stated modeling assumption, not specific-contract IV. Missing independent quote/IV timestamps remain unknown. Source links retain fact dates and limitations; unconfirmed events retain their unconfirmed status. Model version, snapshot version, and calculation assumptions remain discoverable in methodology and research exports.
- **Loading, error, and empty states:** Loading text names the selected symbol and marks the region busy. Data failures use an alert with a reload action. Missing values use an em dash. Missing contracts explain the gap and link to available contract evidence; never fill them with aggregate IV. An empty notebook offers a direct return to scenario research.
- **Research notes:** Saving records a hypothesis, optional invalidation condition, scenario parameters, and data version in this browser. Keep export available and communicate storage failures without claiming a successful save. Restoring an older data version warns that current results may differ; unsupported older parameters stay unavailable. Notes are research records, not executed trades or settled returns.

All views retain the skip link, semantic headings, associated labels, visible gold focus outlines, and native keyboard behavior. Primary actions and mobile assumption controls are at least 44px high; matrix cells are at least 47px high on mobile. Do not equate cell height with a universal 44px width guarantee in this dense table. Long notes and provenance identifiers wrap within their containers.

## Do's and Don'ts

- **Do** keep selection, assumptions, results, units, and limitations understandable together. Preserve the signed matrix and the selected result's stronger hierarchy.
- **Do** keep archived observations, theoretical scenarios, actual contract evidence, and saved hypotheses visibly distinct.
- **Do** scope styling changes to this feature, reuse the incumbent font variables and brand asset, and preserve local overflow at narrow widths.
- **Don't** imply a buy signal from a low IV percentile, a historical win rate without comparable IV history, an event date without confirmation, or coverage of an unconfirmed IPO date by a contract.
- **Don't** turn conditional valuation into a forecast, recommendation, live quote, execution control, or probability claim.
- **Don't** replace missing evidence with invented values or remove timestamps and limitations to simplify the layout.

Reference views: [desktop](../../.impeccable/review/iv-lab/desktop.png), [mobile](../../.impeccable/review/iv-lab/mobile.png), [mobile matrix](../../.impeccable/review/iv-lab/mobile-matrix.png), and [mobile technical chart](../../.impeccable/review/iv-lab/mobile-technical.png). These record the reviewed implementation; future data changes should not alter the design contract.
