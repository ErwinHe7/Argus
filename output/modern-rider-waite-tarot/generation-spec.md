# Modern Rider-Waite Major Arcana — Generation Spec

This 22-card Major Arcana deck is a direct, app-ready modernization of the public-domain Rider-Waite-Smith compositions. It uses the retained Modern Rider-Waite Tarot template for consistent framing, typography, palette, linework, and print texture.

## Inputs

- Style template: `/Users/dickymicky/.codex/skills/artifact-template-modern-rider-waite-tarot/assets/reference.png`
- Composition references: public-domain Rider-Waite-Smith scans from [searge/tarot](https://github.com/searge/tarot), primarily `assets/img/big/major_*.jpg` (`maj04.jpg` and `maj13.jpg` for The Emperor and Death)
- Output: portrait PNG, exactly 950 × 1655 pixels, RGB

## Shared ImageGen prompt

Use image 1 as the strict visual-system reference and image 2 as the composition and symbolism reference. Create a direct contemporary modernization of the referenced Rider-Waite-Smith Major Arcana card. Preserve the recognizable staging, pose, principal objects, and symbolic relationships. Render it as crisp editorial vector illustration with thick navy outlines, simplified geometric shapes, warm ivory framing, saffron/navy/ivory/coral/turquoise/green color blocking, and restrained screen-print grain. Match the template's rounded double border, centered Roman numeral, and bottom title band. Keep the scene legible at mobile-card size. Output a single finished tarot card at a 950:1655 aspect ratio.

Avoid abstract replacement metaphors, changed staging, antique engraving, photorealism, 3D rendering, gradients that weaken the flat-print look, extra captions, incorrect numerals, misspelled titles, and direct copying of the source scan's linework.

## Card-specific briefs

| No. | Card | Required scene and exact label |
| --- | --- | --- |
| 0 | The Fool | Traveler at a cliff with white dog, rose, bundle, mountains, and radiant sun. Numeral `0`; title `THE FOOL`. |
| I | The Magician | Standing creator raises a wand above a table bearing wand, cup, sword, and pentacle; infinity sign and flower garden. Title `THE MAGICIAN`. |
| II | The High Priestess | Seated guardian between dark and light pillars, crescent moon, scroll, veil, and pomegranates. Title `THE HIGH PRIESTESS`. |
| III | The Empress | Crowned figure in a fertile landscape with grain, forest, flowing water, and Venus shield. Title `THE EMPRESS`. |
| IV | The Emperor | Armored ruler on a ram-carved stone throne before red mountains. Title `THE EMPEROR`. |
| V | The Hierophant | Spiritual mentor gives a blessing to two learners above crossed keys. Title `THE HIEROPHANT`. |
| VI | The Lovers | Two partners beneath a radiant angel, with the garden, mountain, tree, and serpent retained. Title `THE LOVERS`. |
| VII | The Chariot | Armored navigator beneath a star canopy, with black and white sphinxes before a city. Title `THE CHARIOT`. |
| VIII | Strength | Calm woman gently closes or holds a golden lion's mouth beneath an infinity sign. Title `STRENGTH`. |
| IX | The Hermit | Cloaked elder on a snowy peak holding a star lantern and staff. Title `THE HERMIT`. |
| X | Wheel of Fortune | Central symbolic wheel with sphinx, serpent, rising figure, clouds, and four winged corner creatures. Title `WHEEL OF FORTUNE`. |
| XI | Justice | Crowned judge between pillars holding an upright sword and balanced scales. Title `JUSTICE`. |
| XII | The Hanged Man | Serene figure suspended upside down from a living T-shaped tree, with radiant halo and crossed leg. Title `THE HANGED MAN`. |
| XIII | Death | Skeletal rider on a white horse advances past figures toward a sunrise between towers. Title `DEATH`. |
| XIV | Temperance | Winged angel pours water between two cups, one foot on land and one in water, with path and sunrise. Title `TEMPERANCE`. |
| XV | The Devil | Horned winged figure above a loosely chained human pair and dark pedestal. Title `THE DEVIL`. |
| XVI | The Tower | Lightning strikes a crowned tower; flames and two falling figures retain the dramatic diagonal action. Title `THE TOWER`. |
| XVII | The Star | Kneeling figure pours water onto land and into a pool beneath one large and seven smaller stars. Title `THE STAR`. |
| XVIII | The Moon | Moon above two towers; dog and wolf flank a winding path while a crayfish emerges from water. Title `THE MOON`. |
| XIX | The Sun | Joyful child rides a white horse with a red banner before sunflowers beneath a radiant sun. Title `THE SUN`. |
| XX | Judgement | Angel sounds a trumpet above people rising with uplifted arms, water and mountains beyond. Title `JUDGEMENT`. |
| XXI | The World | Dancing figure floats within a laurel wreath, surrounded by human, eagle, bull, and lion emblems. Title `THE WORLD`. |

Each card was generated individually with the built-in ImageGen tool, visually inspected, and normalized to the exact output dimensions before packaging.
