---
name: Ritual Investing
description: Market research reframed as an intimate daily ritual.
colors:
  light-page: "#FDEEFD"
  light-surface: "#FFF9FF"
  light-surface-soft: "#F7E4F9"
  light-ink: "#260F2E"
  light-muted: "#6A5570"
  light-primary: "#641D6F"
  light-primary-soft: "#DFB4DE"
  light-gold: "#C6944F"
  light-gold-soft: "#EED3AC"
  light-line: "#DDC4DF"
  light-positive: "#2A6732"
  light-coven: "#4C174F"
  dark-page: "#0B0310"
  dark-surface: "#15061A"
  dark-surface-soft: "#220C28"
  dark-ink: "#F6ECF7"
  dark-muted: "#BDA4C2"
  dark-primary: "#DD94D4"
  dark-primary-soft: "#451D4A"
  dark-gold: "#ECB667"
  dark-gold-soft: "#3D2600"
  dark-line: "#3F2545"
  dark-positive: "#86BE8A"
  dark-coven: "#321036"
typography:
  display:
    fontFamily: "Libre Baskerville"
    fontSize: "30sp"
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "-1sp"
  headline:
    fontFamily: "Libre Baskerville"
    fontSize: "28sp"
    fontWeight: 700
    lineHeight: 1.08
  body:
    fontFamily: "Inter"
    fontSize: "15sp"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Inter"
    fontSize: "12sp"
    fontWeight: 800
    letterSpacing: "1.4sp"
rounded:
  control: "12px"
  surface: "14px"
  feature: "16px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "28px"
components:
  navigation-active:
    backgroundColor: "{colors.light-primary-soft}"
    textColor: "{colors.light-primary}"
    rounded: "{rounded.pill}"
    height: "72px"
  evidence-control:
    backgroundColor: "{colors.light-page}"
    textColor: "{colors.light-primary}"
    rounded: "{rounded.control}"
    padding: "12px 16px"
  coven-feature:
    backgroundColor: "{colors.light-coven}"
    textColor: "{colors.light-surface}"
    rounded: "{rounded.feature}"
    padding: "14px"
---

# Design System: Ritual Investing

## 1. Overview

**Creative North Star: "The Candlelit Observatory"**

The app is an observatory for uncertainty: original tarot art occupies the emotional foreground, while evidence, timing, risk, and simulated portfolio state remain legible underneath. Light mode is lunar and intimate rather than beige or sterile. Dark mode is genuinely nocturnal rather than a quick inversion.

Interaction remains familiar on each operating system. Brand expression belongs in illustration, palette, editorial headings, terminology, and evidence choreography—not in broken back gestures, improvised controls, or hidden disclosures.

**Key Characteristics:**

- Original image-first ritual composition.
- Restrained lilac and aubergine surfaces with rare candle-gold emphasis.
- Editorial serif display moments paired with platform-native sans-serif controls.
- Evidence and Demo state visible in the same flow as the mystical interpretation.
- iOS and Android navigation behavior adapted without duplicating the product UI.

## 2. Colors

The palette moves between a lunar-lilac morning atmosphere and aubergine night while candle gold marks ritual structure and green marks evidence status.

### Primary

- **Blackberry Signal** (`#641D6F` light / `#DD94D4` dark): primary actions, current navigation state, focused fields, and selected constellation nodes.
- **Lunar Lilac** (`#FDEEFD`): the light-mode page field; never replace it with warm parchment or generic white.
- **Aubergine Night** (`#0B0310`): the dark-mode page field; preserve enough separation from the raised night surface (`#15061A`).

### Secondary

- **Candle Gold** (`#C6944F` light / `#ECB667` dark): sigils, ritual labels, meaningful boundaries, and sparing highlights.
- **Coven Plum** (`#4C174F` light / `#321036` dark): Founders’ Coven and high-identity explanatory surfaces.

### Tertiary

- **Evidence Green** (`#2A6732` light / `#86BE8A` dark): market-informed state and simulated positive movement. It never stands alone; copy or an icon carries the same meaning.

### Neutral

- **Blackberry Ink** (`#260F2E`) and **Moon Ink** (`#F6ECF7`): primary readable text.
- **Muted Oracle** (`#6A5570` light / `#BDA4C2` dark): explanatory body text.
- **Veil Line** (`#DDC4DF` light / `#3F2545` dark): separators and boundaries that carry structure.

**The Rare Gold Rule.** Candle gold defines ritual structure; if it becomes the default text or button color, it has lost its meaning.

**The Two Atmospheres Rule.** Dark mode is independently composed. Never mechanically invert the light tokens.

## 3. Typography

**Display Font:** Libre Baskerville with a platform-serif fallback  
**Body Font:** Inter with a platform-sans fallback  
**Label Font:** Inter

**Character:** The serif voice makes readings and section titles feel authored. The sans-serif voice keeps evidence, values, disclosures, controls, and navigation calm and credible.

### Hierarchy

- **Display** (700, `30sp`, 1.05): top-level screen titles and the daily interpretation only.
- **Headline** (700, `28sp`, 1.08): meaningful product sections such as Intentions and Future Mirror.
- **Title** (700, `18–22sp`, 1.1): assets, collections, and feature names.
- **Body** (400, `15–17sp`, 1.45): explanations and disclosures, with readable scaling and no fixed-height containers.
- **Label** (800, `11–12sp`, tracked): rare ritual labels and explicit Demo markers.

**The Split Voice Rule.** Display serif is forbidden in buttons, evidence data, form labels, transaction values, and navigation.

## 4. Elevation

Depth comes primarily from tonal layering. The tarot card alone receives a compact ambient shadow because it is a physical object above the reading stage; lists, fields, navigation, and informational surfaces remain flat.

### Shadow Vocabulary

- **Tarot lift** (`0 6px 8px rgba(0,0,0,0.22)`): only the featured card or a card currently being drawn.

**The One Physical Object Rule.** Never turn every section into a floating card. If more than one neighboring surface has a shadow, remove the weaker shadow.

## 5. Components

### Buttons

- **Shape:** platform-standard controls with gently curved edges (`12px`) or a full pill only when the control is truly compact.
- **Primary:** Blackberry Signal with high-contrast text and a minimum platform touch target.
- **Focus:** two-pixel primary focus treatment plus native semantics; never use color change alone.
- **Secondary:** text or outlined treatment on the current surface; gold is not the default CTA fill.

### Chips

- **Style:** full-pill status labels for Demo and compact filters only.
- **State:** selected state uses both fill and text/icon changes.

### Cards / Containers

- **Corner Style:** `14px` for ordinary thematic surfaces and `16px` for a single feature strip.
- **Background:** tonal surface tokens; Coven Plum is reserved for signature explanatory destinations.
- **Shadow Strategy:** flat except for the featured tarot object.
- **Border:** use Veil Line when a boundary carries meaning; do not combine a border with a wide soft shadow.
- **Internal Padding:** `14–20px` depending on density.

### Inputs / Fields

- **Style:** filled soft surface, `12px` radius, platform-appropriate input behavior.
- **Focus:** two-pixel Blackberry Signal outline and native cursor/keyboard behavior.
- **Error / Disabled:** semantic text and icon accompany the state; never tint placeholder text below accessible contrast.

### Navigation

Navigation is derived from the trusted member capability contract, never a client-side environment guess. Beta uses five destinations in this exact order: Ritual, Starpath, Discover, Coven, You. Production uses Ritual, Starpath, You; Discover and Coven are absent rather than disabled. Missing, expired, or unknown capability data falls back to Ritual only. iOS receives Cupertino tab behavior; Android receives Material navigation behavior. Both preserve the same information architecture, safe-area handling, 44pt/48dp targets, platform back behavior, and branded active color.

### Starpath Learning Path

Starpath is an original downward “Walk the Stars” progression with eight semantic waypoints grouped into four pathways. Alternate waypoints left and right to create a constellation rhythm, but preserve reading, focus, and screen-reader order from one through eight. The connecting line and decorative stars carry no semantics. Starpath waypoints are signature navigation objects rather than ordinary cards and may use the larger rounded constellation shape shown in the approved component.

The hierarchy is fixed: celestial memory frame and no-recommendation boundary, current downward path, optional single recall, then the selected lesson. A lesson reveals one original tarot-style memory card before showing two unmistakable content zones:

1. `MYTHIC MEMORY AID`, immediately followed by “mnemonic—not evidence or a forecast.”
2. `FACTUAL LESSON`, with claim, observed/reviewed dates, source, uncertainty, limitations, risk context, and the definition check.

Completed waypoints remain reviewable, the current waypoint is the only new lesson action, and locked waypoints explain the sequence. Wrong answers use calm factual feedback and retain the choices. Completion adds no streak pressure, lives, countdown, deposit, trade, or security-choice affordance. Rowan opens a bounded sheet containing only reviewed lesson copy, a no-recommendation boundary, and a dismiss action; it has no text field.

At 200 percent text or narrow widths, let headers and waypoint heights grow and preserve downward scrolling. Reduced Motion and accessible navigation remove any nonessential movement; no meaning may depend on flip, bounce, shimmer, parallax, auto-scroll, or the left/right geometry. The visual language may learn from the clarity of guided-learning products but must not copy Alinea, Duolingo, Labyrinthos, or any proprietary character, wording, art, or path composition.

### Daily Ritual Stage

Leonidas and the assigned card form one mobile cinematic stage. The sequence is fixed: date and theme, ritual label, Leonidas standing, assigned card flip, revealed card, Leonidas close-up, reviewed interpretation, evidence invitation, tonight's practice, constellation, Founders’ Coven, optional bounded counsel, Demo limitation. The close-up begins only after a successful reveal; a failed reveal leaves the card concealed and actionable.

Native speech is optional presentation, never authority. Captions contain the complete reviewed script when speech is unavailable, interrupted, or disabled. Reduced Motion and accessible navigation make the transition immediate without changing order or meaning. Leonidas may speak only server-authorized ritual title, interpretation, counsel, and risk footer. Evidence remains one gesture from the interpretation, and no romance, character affinity, urgency, or animation may cross into a financial action.

## 6. Do's and Don'ts

### Do:

- **Do** use the preserved Compass, Leonidas, and bounded Rowan assets as visual-fidelity anchors for their assigned surfaces.
- **Do** keep factual observations, timestamp, uncertainty, and Demo status adjacent to every investment idea.
- **Do** preserve system back gestures, safe areas, text scaling, VoiceOver, TalkBack, and reduced-motion behavior.
- **Do** distinguish founder, owner, and chief-executive inclusion categories with a visible verification date.
- **Do** let Leonidas explain Daily Ritual evidence and uncertainty while leaving the decision with the user; keep other Rowan surfaces bounded to their reviewed context.
- **Do** keep Starpath mythic copy visually and semantically separate from its factual source, dates, limitations, and risk context.

### Don't:

- **Don't** build generic navy-and-green brokerage dashboards with mystical decoration added afterward.
- **Don't** use juvenile horoscope art, novelty occult clip art, or an uncurated “Etsy witch” collage.
- **Don't** directly copy Labyrinthos, Alinea, or their proprietary characters, wording, and interface patterns.
- **Don't** hide market influence, imply supernatural guarantees, or design disclosure language to escape notice.
- **Don't** use romance, urgency, jealousy, exclusivity, or sexual pressure to influence a financial decision.
- **Don't** add side-stripe accents, gradient text, decorative glassmorphism, nested card grids, or radii above `16px` on ordinary surfaces.
- **Don't** add recommendations, rankings, guarantees, urgency, suitability, personalized security choices, or astrology presented as investment causation to Starpath.
