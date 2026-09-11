---
name: Leo investing workspace
description: Scoped visual contract for the security directory, broker setup preview and local personal trading desk.
colors:
  aubergine: "#0d0912"
  raised-aubergine: "#15101d"
  selected-aubergine: "#23182c"
  hover-aubergine: "#1c1423"
  ink: "#f6ecf7"
  muted-ink: "#c5b5ce"
  quiet-ink: "#ad9ab7"
  gold: "#ecb667"
  gold-hover: "#f3c689"
  gold-ink: "#21131b"
  lilac: "#d9a4df"
  sage: "#91c7af"
  divider: "#372a40"
  field-border: "#53415e"
  action-border: "#715878"
  ready-border: "#56846e"
  error-bg: "#2b2028"
  error-border: "#624252"
  error-ink: "#f1ccd3"
  notice-bg: "#13231e"
  notice-border: "#476758"
  notice-ink: "#bfdfce"
typography:
  display:
    fontFamily: "Instrument Serif, Georgia, serif"
    fontSize: "clamp(42px, 4.5vw, 64px)"
    fontWeight: 400
    lineHeight: 1.06
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Instrument Serif, Georgia, serif"
    fontSize: "37px"
    fontWeight: 400
  body:
    fontFamily: "Inter, sans-serif"
    fontSize: "14px"
  label:
    fontFamily: "Inter, sans-serif"
    fontSize: "11px"
  personal-headline:
    fontFamily: "Instrument Serif, Georgia, serif"
    fontSize: "32px"
    fontWeight: 400
    lineHeight: 1.2
  ticket-headline:
    fontFamily: "Instrument Serif, Georgia, serif"
    fontSize: "29px"
    fontWeight: 400
    lineHeight: 1.2
  workflow-title:
    fontFamily: "Inter, sans-serif"
    fontSize: "17px"
    fontWeight: 500
    lineHeight: 1.5
  personal-copy:
    fontFamily: "Inter, sans-serif"
    fontSize: "13px"
    lineHeight: 1.8
  personal-label:
    fontFamily: "Inter, sans-serif"
    fontSize: "12px"
rounded:
  control: "6px"
  outline-action: "7px"
  notice: "8px"
  detail: "12px"
spacing:
  compact: "12px"
  control-gap: "16px"
  panel: "24px"
  section-gap: "32px"
  desktop-gutter: "44px"
components:
  button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.gold-ink}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
  button-primary-hover:
    backgroundColor: "{colors.gold-hover}"
  button-outline:
    textColor: "{colors.ink}"
    rounded: "{rounded.outline-action}"
    padding: "12px 18px"
  field:
    backgroundColor: "{colors.raised-aubergine}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    height: "46px"
  detail-card:
    backgroundColor: "{colors.raised-aubergine}"
    textColor: "{colors.ink}"
    rounded: "{rounded.detail}"
    padding: "27px 24px"
  personal-button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.gold-ink}"
    rounded: "{rounded.control}"
    padding: "12px 17px"
  personal-field:
    backgroundColor: "{colors.aubergine}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    height: "46px"
  order-ticket:
    backgroundColor: "{colors.raised-aubergine}"
    textColor: "{colors.ink}"
    rounded: "{rounded.detail}"
    padding: "25px 24px"
  personal-error:
    backgroundColor: "{colors.error-bg}"
    textColor: "{colors.error-ink}"
    rounded: "{rounded.notice}"
    padding: "16px 20px"
  personal-notice:
    backgroundColor: "{colors.notice-bg}"
    textColor: "{colors.notice-ink}"
    rounded: "{rounded.notice}"
    padding: "16px 20px"
---

# Design System: Leo investing workspace

## Overview

**Creative North Star: "Leo's research workspace"**

This is a narrow extension of the implemented [Market Map world](../market-map/DESIGN.md), scoped to this component folder and its two routes. It covers the stock directory, the default three-broker setup preview, and the opt-in local personal branch of `/brokers`. The built components and their shared and personal stylesheets are the authority. It does not replace platform-wide product or design guidance.

Dark aubergine, editorial serif headings, restrained gold actions and lilac links carry Leo's identity into a calm working surface. Dense results remain easy to scan; explanatory detail receives its own space.

**Key Characteristics:**

- Clear hierarchy between a directory entry, research availability and setup status.
- Flat section divisions with a raised selected-security panel.
- Native controls, visible focus and explicit unavailable states.
- A distinct manual order ticket beside personal account setup or returned account information.

## Colors

Gold anchors primary actions, active navigation and keyboard focus. Lilac distinguishes secondary research and external links. Sage marks available research, connected account status and completed setup checks, always accompanied by text. Completed step markers use the ready border. Aubergine tonal changes distinguish page, panel, selection and hover; the three ink levels separate content, explanation and metadata.

Personal request errors use the muted rose error surface, border and ink. Informational or successful task notices use the green notice surface, border and ink. These semantic extensions describe returned task state; they are not new brand accents. The unconnected status dot uses quiet ink and the written “Account not connected” label.

**The Status Rule.** Color supports a written capability state; it never supplies the state alone.

## Typography

Instrument Serif presents the wordmark, page titles, broker heading and explanatory section headings. Inter carries controls, table content and supporting copy with tabular numerals. The serif is upright here; no new font family is introduced.

The display role scales on desktop and becomes 45px on mobile. Broker headings step from 37px to 33px; lower editorial headings use 31px. Table content and descriptions use compact Inter sizes, with generous line height for multi-line explanation. Main introductory copy is limited to 65ch.

The personal desk starts directly with its page heading. Its connection and account headings use the personal headline role; the connection heading becomes 30px on mobile. Positions and broker-orders headings use 28px serif type. The ticket uses the smaller ticket headline role. Review and submission-result headings use the Inter workflow title role so state changes read as working information. Personal labels, table values and order details use 12px Inter; field values and task feedback use 13px. Quiet metadata starts at 11px, with ticket introduction and bottom notes increased to 12px on mobile. Balances use 19px Inter, becoming 17px at the middle breakpoint. Preserve the shared button font inheritance when documenting rendered controls; a single-class personal button declaration does not override the shared page button rule.

## Layout

The centered header has a 1560px maximum width; main content and footer use 1460px. Desktop gutters are 44px, becoming 24px at 1100px and 16px at 760px. The heading and route-level secondary action share a row until mobile.

Discovery uses a filter band, results table and a 310px detail column, reduced to 280px at the middle breakpoint. Search and three filters occupy four columns on wide screens and two below 1100px. On mobile, search and coverage each span the row; exchange and type share one row. The selected detail panel moves above results and loses sticky positioning. An unselected empty detail panel is hidden on mobile. Long names truncate in rows and wrap in the detail panel; the table has its own overflow container.

The default broker setup preview uses a 340px chooser beside a detail area capped at 680px, with a 64px gap. At 1100px the chooser becomes 270px and the gap 35px. At 760px the chooser becomes three horizontal tabs above the detail. The future order-flow explanation stacks from three columns into one. Header account access is hidden at this breakpoint while the three investing routes remain visible.

The personal branch uses a flexible account area beside a 365px order ticket, with a 54px gap. At 1100px the ticket becomes 320px and the gap 28px; the three account balances become individual rows. At 760px the account area precedes a full-width ticket with a 32px gap. The desktop ticket is sticky at 24px and becomes static on mobile. Ticket padding steps from 25px 24px to 23px 20px at the middle breakpoint. Quantity and limit price retain two equal columns. Positions and broker orders scroll within their own table containers. The connection bar wraps on mobile and hides its secondary location text.

“Find my accounts” sits directly below the connection introduction, before the setup steps. Task feedback appears at the start of the account area or inside the ticket according to the action that produced it. Review and submission results stay within the ticket's reading order.

## Elevation & Depth

Depth comes from tonal layering and thin borders. This component set uses no box shadows, gradients or floating overlays. Hover changes the surface tone without lifting content. Reduced-motion preferences remove transitions and smooth scrolling.

## Shapes

Controls use small rounded corners; the selected-security panel and personal order ticket have the larger detail radius. Tables, broker rows and explanatory sections use straight dividers. Gold primary actions and bordered secondary actions remain compact rectangles. Personal setup uses 28px circular numbered/check markers; connection readiness uses a small dot beside text. There are no status pills in this implementation.

## Components

**Workspace navigation.** The lion and serif wordmark return home. Stocks and Brokers expose the active route through gold text, a bottom border and `aria-current`. A skip link appears on focus. Interactive focus uses a 2px gold outline with 4px offset.

**Search and filters.** Labelled native search/select controls are 46px high. Filter changes reset pagination and selected detail. Search waits 250ms before fetching; superseded requests are aborted. During loading, the result region exposes `aria-busy`, announces “Searching…” and disables row and paging actions while retaining the previous rows. Failure hides the result table and shows an alert with “Try again”. Empty results give a specific message and suggest a different query or broader filters.

**Security results and coverage.** Each semantic table row offers a named coverage action and a selected tonal state. Research uses “Available” or “Data needed”. Detail separately identifies verified listing, current Market Map, unavailable predictive ranking and required broker setup. Only a returned research snapshot exposes “Open Market Map”, with observation cutoff and source. Missing research remains explicit. The initial selection is the first research-covered entry when present; a single search result selects itself. Pagination uses labelled 44px controls and truthful disabled boundaries.

**Actions.** Primary links use gold with a lighter hover state. Outline actions retain the page background and turn gold on hover. Lilac text links have generous vertical hit areas. Disabled setup uses reduced opacity and a disabled cursor; its copy communicates the reason.

**Default broker selection and setup preview.** Interactive Brokers, moomoo and Webull are tabs with one tab stop, selected state, a labelled focusable panel, wrapping arrow-key navigation, and Home/End navigation. Selection updates the provider content. Every provider in this default branch shows “Setup required”, “Not connected”, a connection-unavailable explanation and a disabled setup action. The native details disclosure reveals prerequisites and official documentation; external broker links do not activate a connection. A security context strip explicitly states that no order exists. This disabled-preview rule does not apply to the personal branch.

**Personal connection and account controls.** The local development branch offers working moomoo SDK account discovery and connection requests. “Find my accounts” remains a bordered action; eligible returned accounts populate a labelled native select, with Paper/Real mode and masked account suffix. A selected account enables the gold connection action. Readiness checks distinguish an available SDK, reachable OpenD and a connected account; one state must not be presented as proof of another. Connected content shows returned balances, snapshot time, positions and broker orders, with explicit unavailable or empty text. Refresh and Disconnect remain native buttons. A native details/summary disclosure contains the optional password input for broker-session unlock. Implemented connected states do not establish a completed owner login; the evidence boundary is in the matching surface brief.

**Manual order ticket.** The raised panel contains a native form and fieldset, labelled symbol input, Buy/Sell select, whole-share quantity input and USD limit-price input. Native required/pattern validation and numeric/decimal input hints support entry. The ticket can be filled before connection; review requires a connected permitted account and no pending submission. A disconnected ticket explains “Connect an account to review an order.” A real account with live ordering disabled receives the launcher recovery immediately beside the disabled review action. Busy work or a pending submission disables the fields. Personal field backgrounds use the page aubergine within the raised ticket; this differs from the directory search field.

**Review and submission states.** A returned review lists the masked account, exact order, limit price, notional, local cap, expiry and any returned warnings. A native checkbox acknowledges that exact Paper/Real order before the explicit confirmation button becomes available. Successful review focuses its heading; confirmation replaces review with a focusable submission-result heading. Pending review recovery presents “Check order status”; an unknown outcome keeps a new ticket blocked. “Discard unused review” appears only when no command was returned, and “Start a new order” appears only for a known submitted or rejected result. Submission is explicitly distinguished from a fill. Research links do not create an order.

**Personal task feedback.** Errors retain `role="alert"` and notices retain `role="status"`; both are programmatically focusable and placed beside the originating account or order task. Feedback and review/result heading focus use a 2px gold outline with 5px offset. Feedback has 28px scroll margin. The submission section also uses a polite live region. Status text, focus and disabled controls carry the state alongside its semantic color.

## Do's and Don'ts

- **Do** inherit the existing Leo palette, typography and restrained use of accent color.
- **Do** preserve written capability states, source context and keyboard affordances.
- **Do** keep unavailable research and broker setup visually legible and actionable only within their actual state.
- **Do** distinguish the default disabled setup preview from the opt-in personal account and manual order flow.
- **Do** keep task feedback, account mode, review acknowledgement and recovery actions adjacent to the work they explain.
- **Don't** turn directory membership or conditional simulations into a predictive rank or recommendation.
- **Don't** style a disabled broker preview as an active account connection or order submission.
- **Don't** apply this local page composition as a global redesign requirement.
