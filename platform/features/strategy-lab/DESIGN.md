---
name: Strategy Workspace
description: Astra's aubergine and candle-gold language for deterministic strategy setup, local research, and paper-account evidence.
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
  secondary-action: "#21172b"
  secondary-hover: "#30213d"
typography:
  headline:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "40px"
    fontWeight: 750
    lineHeight: 1.15
    letterSpacing: "-0.03em"
  title:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "23px"
    fontWeight: 650
    letterSpacing: "-0.025em"
  section:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "21px"
    fontWeight: 650
    letterSpacing: "-0.02em"
  body:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "13px"
    lineHeight: 1.7
  introduction:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "14px"
    lineHeight: 1.7
  label:
    fontFamily: "DeskInter, Inter, sans-serif"
    fontSize: "12px"
rounded:
  square: "0px"
  field: "4px"
spacing:
  compact: "8px"
  control: "12px"
  inset: "16px"
  mobile-gutter: "18px"
  tablet-gutter: "24px"
  section: "30px"
  workspace-gap: "32px"
components:
  button-primary:
    backgroundColor: "{colors.candle-gold}"
    textColor: "{colors.action-ink}"
    rounded: "{rounded.square}"
    padding: "11px 16px"
  button-primary-hover:
    backgroundColor: "{colors.gold-hover}"
  button-border:
    backgroundColor: "{colors.secondary-action}"
    textColor: "{colors.ink}"
    rounded: "{rounded.square}"
    padding: "11px 16px"
  button-border-hover:
    backgroundColor: "{colors.secondary-hover}"
  button-text:
    textColor: "{colors.candle-gold}"
    rounded: "{rounded.square}"
    padding: "11px 0"
  button-pause:
    textColor: "{colors.loss-red}"
    rounded: "{rounded.square}"
    padding: "11px 12px"
  input:
    backgroundColor: "{colors.field}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "10px 12px"
  step:
    textColor: "{colors.muted}"
    rounded: "{rounded.square}"
    padding: "9px 12px"
  step-current:
    textColor: "{colors.candle-gold}"
  selected-strategy:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    rounded: "{rounded.square}"
    padding: "26px 22px"
---

# Design System: Strategy Workspace

## Overview

**Creative North Star: "Aubergine market analyzer"**

Strategy Workspace continues Astra's existing visual identity: deep aubergine surfaces, candle-gold actions, lilac evidence, compact self-hosted Inter, and the retained Leo Lion in the surrounding shell. Flat divisions and concise labels keep rules, recorded evidence, and control state legible.

This document records the built feature in [StrategyWorkspace.tsx](StrategyWorkspace.tsx), [strategy.css](strategy.css), [AccountEvidence.tsx](AccountEvidence.tsx), [ResearchEvidence.tsx](ResearchEvidence.tsx), [GridResearch.tsx](grid/GridResearch.tsx), and [grid.css](grid/grid.css). Shared primitives come from [desk.css](../research-desk/desk.css) and the incumbent [Astra design system](../research-desk/DESIGN.md). Its scope is this feature; its composition and verification status are recorded in the [surface brief](.impeccable/surfaces/strategy-workspace-tsx.md).

**Key Characteristics:**

- Aubergine surfaces, fine plum rules, and square action shapes.
- Candle-gold selection and actions, with explicit words beside state colors.
- Compact Inter headings and tabular account values.
- Ruled evidence sections with source, time, and limitations kept close to the data.

## Colors

Warm gold guides action across a dark purple working field; status and evidence accents carry supporting meaning.

### Primary

- **Candle gold:** primary actions, the current setup step, disclosure links, pairing actions, pending or paused state text, and the replay equity line and comparison row. Gold hover lightens the primary action; a gold replay value identifies the approach, not a positive return.
- **Action ink:** dark text on the gold action surface.

### Secondary

- **Lilac:** strategy version identifiers, evidence categories, connector imagery, and the cash benchmark line.
- **Observed green:** the reported Running label.
- **Loss red:** failure-case copy, error framing, latched loss-trigger state, and the Pause entries control.

### Neutral

- **Aubergine:** the inherited page background.
- **Panel:** selected strategy and authentication surfaces.
- **Rule:** structural divisions across strategies, evidence, tables, and the monitor.
- **Ink and muted:** primary reading and supporting explanations.
- **Field and field-rule:** editable surfaces and their boundaries.
- **Secondary action and secondary hover:** bordered action surfaces.

**The State Label Rule.** Color supports explicit state text; it does not replace acknowledgement, freshness, or protection labels.

## Typography

The inherited variable Inter font is self-hosted as DeskInter with swap loading. It supplies both headings and body text. The frontmatter records the desktop roles used here; the page heading becomes 32px at the feature's mobile breakpoint. The step title is followed by short introductory copy, then compact working details. Section titles vary by importance: recorded activity and the supervisor use the section role; the local monitor and research report use smaller headings.

Body copy usually uses 12px to 14px with 1.7 or 1.8 leading. Paragraphs are bounded at 72ch, and action explanations are shorter. Account and replay totals, tables, chart axes, step numbers, and event times use tabular numerals. Pairing tokens and raw event payloads retain monospace formatting for copying and inspection. Phone inputs, selects, and the question textarea use 16px text; the read-only pairing token retains its smaller monospace treatment. Chart geometry scales separately from its HTML axis labels so shrinking the plot does not shrink the text.

**The Concrete Label Rule.** Small labels identify a field, source, time, rule version, evidence category, or state.

## Layout

The feature is centered within 1680px with percentage desktop gutters and a 32px workspace gap. Its primary grid combines a flexible setup area with a 310px monitoring rail. At 1150px and below, gutters become 24px, the rail becomes 270px, and the gap becomes 22px.

At 800px and below, the layout becomes one column with 18px gutters. The local monitor moves above setup and loses sticky positioning. Device fields, account tables, and the supervisor stack. Account values become aligned label/value rows. Tables and raw payloads retain their own horizontal scrolling regions when necessary.

Ruled rows organize options, revisions, account reports, and recorded activity. They are separated by content hierarchy and space rather than independent floating cards. The five-step sequence, mobile wrapping, and navigation behavior are surface-specific and documented in the surface brief.

Compact comparisons keep their label and numeric columns together on phones, with wrapping labels and right-aligned amounts. Genuinely wide ledgers retain their own keyboard-focusable scrolling region. Replay fields and headline totals use paired columns until the narrow-phone breakpoint (480px), then stack; mobile action groups expand to the available width.

**The Comparison Width Rule.** Fit compact comparisons to the content width; reserve local horizontal scrolling for ledgers that need it.

## Elevation & Depth

The feature uses no box shadows. Tonal selection, one-pixel rules, and visible focus outlines establish hierarchy. Focus uses a gold two-pixel outline offset by four pixels. Selection and the text caret use gold.

New step content has a short 180ms ease-out clipping reveal. Reduced-motion preferences disable that animation; step navigation uses an immediate scroll and focuses the new heading without a second scroll. This motion marks a content change without delaying access to the controls.

Replay loading uses a small line-icon spinner with a status message. Reduced-motion preferences stop the rotation while keeping the message visible. A completed replay focuses its newly committed result heading so the result has a clear reading destination.

**The Flat Surface Rule.** Build hierarchy with tone, rules, type, and selection rather than decorative elevation.

## Shapes

Actions, step markers, option rows, evidence sections, and monitor divisions use square forms. Inputs have the restrained field radius. Native radio buttons and checkboxes retain familiar control shapes with gold selection. Lucide line icons support actions and connector status; the existing Lion belongs to the retained Astra shell. This feature adds no new raster artwork.

## Components

### Buttons

Primary actions use gold with dark text; secondary actions use a plum surface and a lighter border. Text actions use gold without a filled container. Shared action controls have a 44px minimum height. Pause entries uses red text and border on a transparent surface, with a panel-colored hover. Disabled controls lower opacity and use the unavailable cursor. All focusable controls receive the feature's visible gold focus treatment.

### Inputs and consent

Fields keep visible labels, a dark inset surface, a light plum boundary, and a minimum height of 44px. Muted descriptions stay close to the related control. The execution-mode radios and explicit authorization checkbox preserve their native semantics. Pairing tokens are read-only and selectable; the adjacent Copy action reports success or a manual-copy fallback.

### Strategy rows and disclosures

Each strategy is a native radio choice inside a full clickable ruled row. The selected row has a panel surface. A compact title/version line leads into the premise, character, and a Rules and failure cases disclosure. Failure text remains visible within that disclosure in the loss color. Saved revisions use full-width ruled rows with a trailing arrow.

### Setup navigation

Numbered buttons expose the actual sequence. The current button uses gold text, a gold bottom rule, and a gold outline around its number; other steps use muted text and structural rules. The mobile rail shows all five controls in a three-column grid. Step changes focus the newly mounted heading, preserving a clear reading destination.

### Grid research evidence

Replay reports use the inherited flat, ruled evidence sections. Total marked portfolio P&L and remaining inventory receive the strongest numeric emphasis; cycle profit is subordinate accounting detail. Synthetic or unverified source labels remain beside the loaded input and result heading. Empty, busy, error, and completed states use explicit words and the same action hierarchy as the paper workspace.

The equity chart pairs a solid gold portfolio line with a dashed lilac cash line, a text legend, and an accessible title and description. SVG carries geometry; fixed-size HTML labels carry axis values and dates. The ending comparison keeps all three columns visible on phones, with the replay row in gold and tabular numbers aligned right. Journal events and long identifiers use separate native disclosures; source, dates, and limitations remain directly readable. The detailed workflow and exact mobile treatment belong to the surface brief.

### Local monitor behavior

Connector identity, heartbeat age, mandate state, broker connectivity, quote age, reconciliation, and local protection use compact labeled rows. Pause and resume remain distinct controls. Pending acknowledgement is expressed in words. Stale data keeps its last reported values and presents unavailable protection explicitly. The caution about pending orders and existing positions stays beside the controls.

### Evidence and conversation

Account evidence keeps its reporting time beside the account identity; missing fields say Not reported rather than showing invented zeroes. Positions and working orders use compact, labeled tables inside keyboard-focusable scrolling regions. Research summaries show Exploratory · not promoted with their source and cutoff, and expose limitations and hashes in a disclosure. Recorded events reveal raw payloads beneath their summary and time. The supervisor uses a scoped question field and chronological answers with evidence-reference counts; it does not visually imply control authority beyond its stated pause request.

## Do's and Don'ts

### Do:

- **Do** reuse the inherited aubergine, gold, Inter, and Lion identity.
- **Do** keep state words, timestamps, and limitations beside the evidence or control they qualify.
- **Do** preserve visible keyboard focus and native field semantics.
- **Do** retain local scrolling for wide account tables and raw event payloads.
- **Do** keep compact comparison columns visible together and chart labels independent of plot scaling.

### Don't:

- **Don't** turn the feature's flat evidence sections into decorative elevated cards.
- **Don't** let color imply that a request is acknowledged or that local protection is available.
- **Don't** present missing, stale, or exploratory data as current validated performance.
