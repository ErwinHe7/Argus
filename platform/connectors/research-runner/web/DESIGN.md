---
name: Continuous Research Monitor
description: Astra's inherited aubergine and candle-gold language for local research status and source evidence.
colors:
  candle-gold: "#ecb667"
  gold-hover: "#f6c782"
  action-ink: "#261c17"
  observed-green: "#a3d2ba"
  loss-red: "#f0a8a1"
  aubergine: "#0d0912"
  panel: "#17101f"
  rule: "#382a43"
  ink: "#f6edf7"
  muted: "#bfafca"
  field-rule: "#594463"
  secondary-hover: "#30213d"
typography:
  headline:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "clamp(30px, 3.4vw, 42px)"
    fontWeight: 750
    lineHeight: 1.15
    letterSpacing: "-0.03em"
  section:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "21px"
    fontWeight: 650
    lineHeight: 1.3
    letterSpacing: "-0.02em"
  body:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "14px"
    lineHeight: 1.7
  detail:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "13px"
  label:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "12px"
rounded:
  square: "0px"
spacing:
  compact: "8px"
  control-gap: "10px"
  content-gap: "12px"
  mobile-gutter: "18px"
  row-gap: "22px"
  roomy: "40px"
components:
  button-primary:
    backgroundColor: "{colors.candle-gold}"
    textColor: "{colors.action-ink}"
    rounded: "{rounded.square}"
    padding: "10px 17px"
  button-primary-hover:
    backgroundColor: "{colors.gold-hover}"
  button-secondary:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    rounded: "{rounded.square}"
    padding: "10px 17px"
  button-secondary-hover:
    backgroundColor: "{colors.secondary-hover}"
  job-row:
    textColor: "{colors.ink}"
    padding: "20px 0"
  coverage-disclosure:
    textColor: "{colors.ink}"
    padding: "14px 0"
---

# Design System: Continuous Research Monitor

## Overview

**Creative North Star: "Aubergine market analyzer"**

The monitor continues the established Strategy Workspace identity: deep aubergine, candle-gold actions, compact self-hosted Inter, and the retained Lion. Fine rules and clear type organize a flat working surface.

This scoped record describes the built [stylesheet](monitor.css), [markup](index.html), and [state rendering](monitor.js). Its visual authority is the existing [Strategy Workspace design system](../../../features/strategy-lab/DESIGN.md). The workflow, capability limits, and verification evidence belong to the [surface brief](.impeccable/surfaces/monitor.md).

**Key Characteristics:**

- Inherited aubergine, candle gold, Inter, and Lion.
- Square actions and flat ruled information rows.
- Explicit state words beside heartbeat age and control feedback.
- Compact labels, readable reasons, and tabular counters.

## Colors

Warm gold directs action and attention across a dark purple working field.

### Primary

- **Candle gold:** primary action, pending or recorded job states, notices, and disclosure conditions. Gold hover lightens the primary action.
- **Action ink:** dark text on the gold action and selection background.

### Secondary

- **Observed green:** the ordinary status band; the accompanying words identify the reported state, including paused status.
- **Loss red:** the status band when freshness is lost or the worker reports an error, stopped, stopping, or unavailable state.

### Neutral

- **Aubergine:** the page background.
- **Panel and secondary hover:** the secondary action's resting and hover surfaces.
- **Rule and field-rule:** fine section divisions and the secondary action boundary.
- **Ink and muted:** primary reading and supporting labels, timestamps, reasons, and limitations.

**The State Label Rule.** Color supports explicit state text; it does not replace acknowledgement or freshness labels.

## Typography

The variable Inter asset is self-hosted as DeskInter with swap loading and supplies all text. The headline responds to viewport width; section headings step down to 20px at the mobile breakpoint. Job names use 15px semibold text. Supporting detail and labels sit below the body role without introducing another font.

Counter values use 23px semibold tabular numerals. Introductions are bounded at 65ch, job reasons at 70ch, and explanatory notes at 75ch. Long reasons wrap within their column.

**The Concrete Label Rule.** Small labels identify a source, time, job type, state, or measured counter.

## Layout

The working area is centered within 1120px, with 32px horizontal padding and 45px vertical padding. The desktop heading shares a row with the actions. Ruled job rows pair a 190px identity column with a flexible explanation column. Totals form a compact horizontal group; source disclosures follow the same flat row grammar.

At 700px and below, the main padding becomes 30px by 18px. Actions wrap and expand, the status band stacks, totals use two columns, job rows become one column, and disclosure conditions occupy their own line. The precise reading sequence is specific to this surface and remains in its brief.

**The Readable Row Rule.** Keep explanations in the normal reading flow and stack their columns on narrow screens.

## Elevation & Depth

The monitor uses no shadows or animated transitions. Background tone, one-pixel rules, spacing, and weight establish hierarchy. Keyboard focus uses a gold two-pixel outline offset by four pixels on buttons and disclosure summaries. The reduced-motion rule retains automatic scrolling behavior.

**The Flat Surface Rule.** Build hierarchy with tone, rules, type, and focus rather than decorative elevation.

## Shapes

Both action variants have square corners. Ruled rows and native disclosures carry the same straight geometry without separate card silhouettes. The existing Lion remains the sole identity image; the monitor introduces no new artwork or icon system.

**The Square Action Rule.** Keep primary and secondary actions square, consistent with Strategy Workspace.

## Components

### Buttons

The primary action uses gold and dark text; Refresh uses a panel surface, light text, and the lighter plum boundary. Both have a minimum height of 44px. Hover changes the fill; focus adds the shared outline. Disabled actions use half opacity and a default cursor.

The primary label changes between Pause research and Resume research. A submitted request keeps its requested label and stays disabled until the next status acknowledges it. Busy, stale, failed, and shutdown states also disable this control. A notice explains an accepted request or control error.

### Status band and notices

The headline, state words, heartbeat age, and band color work together. Stale status and a disconnected fetch preserve the last counters and rows while disabling control. Disconnection explicitly marks the retained values as potentially outdated. Notices use gold text in the reading flow and expose status semantics.

### Counters

Definition-list labels remain attached to their tabular values. Recorded input batches and Rust replays are separate counts. Missing values use an em dash. AI calls displays zero only when the status reports zero; the client rejects unexpected status contracts.

### Job rows

A compact job name and type lead into state and reason. Gold highlights the state; muted prose explains the result or missing evidence. Empty queues receive an inline explanation using the same restrained text hierarchy.

### Source disclosures

Native details and summary elements group the symbol, observed-session count, and evidence condition. Opening a row reveals the history range and missing-evidence list. Open rows remain open across status refreshes. An empty source area explains that a source check will provide the history and evidence.

## Do's and Don'ts

### Do:

- **Do** reuse the inherited aubergine, gold, Inter, and Lion identity.
- **Do** keep state words, heartbeat age, and feedback beside the control they qualify.
- **Do** preserve visible keyboard focus and native disclosure semantics.
- **Do** distinguish recorded input batches from Rust replays in labels and counts.

### Don't:

- **Don't** turn the flat ruled sections into decorative elevated cards.
- **Don't** let color imply that a request is acknowledged or that a stale value is current.
- **Don't** present missing source evidence as completed research or validated performance.
