# Modern Vector Tarot — Major Arcana Generation Specification

Generated with the built-in ImageGen workflow using two references per new card:

1. `artifact-template-modern-vector-tarot/assets/reference.png` controls the visual system.
2. The matching public-domain Rider–Waite image from `searge/tarot` identifies the card and its traditional meaning only.

The approved Fool is the retained template image. Cards I–XXI were generated as separate assets.

## Shared prompt scaffold

```text
Use case: style-transfer
Asset type: one portrait Major Arcana card for a polished mobile app deck
Primary request: Create card <numeral>, <title>, as a genuinely original contemporary interpretation of <meaning>.
Input images: Image 1 is the mandatory Modern Vector Tarot template reference; preserve its rounded border, top numeral placement, bottom title band, geometric editorial-vector language, high-contrast palette, midnight outlines, and subtle screen-print texture. Image 2 is the public-domain Rider–Waite source for card identity and meaning only; do not copy its visible composition, pose, costume, objects, or scenery.
Original scene: <card-specific contemporary metaphor>
Composition: one strong central visual metaphor with thumbnail readability.
Text (verbatim): top numeral "<numeral>"; bottom title "<title>" in centered bold geometric sans-serif.
Constraints: preserve meaning while replacing historic staging; use midnight navy, warm ivory, saffron, coral, turquoise, and muted sage; keep the deck unified with Image 1.
Avoid: obvious Rider–Waite staging, vintage engraving, photorealism, 3D rendering, illegible text, extra captions, logos, and watermarks.
```

## Card-specific direction

| No. | Title | Original contemporary metaphor |
|---|---|---|
| 0 | THE FOOL | A traveler crosses a circular threshold from an orderly grid into open geometric possibility, guided by a paper bird. |
| I | THE MAGICIAN | A creator in a modular studio combines four elemental modules into one luminous constructed form. |
| II | THE HIGH PRIESTESS | A night archivist listens as overlapping translucent planes reveal a hidden star map and luminous inner thread. |
| III | THE EMPRESS | A gardener-designer nurtures a communal rooftop ecosystem producing fruit, flowers, craft, and connection. |
| IV | THE EMPEROR | A civic architect aligns interlocking city blocks around a protected central courtyard. |
| V | THE HIEROPHANT | A mentor and learning circle assemble inherited symbols into an evolving suspended tessellation. |
| VI | THE LOVERS | Two equal travelers bring separate translucent halves together while an open third path makes choice visible. |
| VII | THE CHARIOT | A navigator guides two opposing motion ribbons into one disciplined forward route. |
| VIII | STRENGTH | A calm figure transforms a turbulent coral storm-knot into a protective spiral around a glowing center. |
| IX | THE HERMIT | A solitary seeker follows one luminous thread inward through a rooftop labyrinth. |
| X | WHEEL OF FORTUNE | A circular transit system carries travelers through four seasonal zones and an unpredictable central interchange. |
| XI | JUSTICE | A mediator realigns a fractured civic mosaic while action paths connect visibly to their outcomes. |
| XII | THE HANGED MAN | A person floats peacefully in a room rotated ninety degrees, choosing a radically different perspective. |
| XIII | DEATH | A traveler crosses a threshold where obsolete structures dissolve into seeds, leaves, and new forms. |
| XIV | TEMPERANCE | A sound artist blends jagged and gentle waveforms through a prism into one balanced golden rhythm. |
| XV | THE DEVIL | A person recognizes and opens a self-reinforcing loop of attention, temptation, and restriction. |
| XVI | THE TOWER | A brittle sealed grid splits open and reconfigures into flexible bridges, arches, and public space. |
| XVII | THE STAR | A rooftop figure reconnects scattered lights into a constellation that renews a dark neighborhood. |
| XVIII | THE MOON | A traveler navigates a mirrored night maze where conflicting shadows suggest uncertain paths. |
| XIX | THE SUN | A joyful public solar garden fills with shared movement, music, food, play, and warmth. |
| XX | JUDGEMENT | A dawn pulse opens translucent shells around people who step toward a renewed shared center. |
| XXI | THE WORLD | A traveler moves through one continuous ring connecting city, garden, coast, and night sky. |

## Output standard

- Format: PNG
- Dimensions: 950 × 1655 pixels
- Color: RGB
- Count: 22 Major Arcana cards
