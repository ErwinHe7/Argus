# Leonidas — Blender courtyard pilot

The first story, **The Unfinished Garden**, now uses an original Blender-rendered
observatory courtyard. The table holds a garden plan and botanical specimen;
the surrounding planting beds remain empty. It is a visual memory aid, not a
claim about investment outcomes.

## Files

- `build_garden.py` rebuilds all geometry, procedural materials, lights and camera.
- `garden-v1/leonidas-garden-v1.blend` is the editable scene.
- `garden-v1/leonidas-garden-blender-v1.png` is the 1536 × 1152 render.
- `garden-v1/provenance.json` records the renderer and source. The PNG also embeds
  source information. There are no external model or texture dependencies.

The app uses a copy of the PNG at
`ritual-investing-app/assets/images/leonidas/leonidas-garden-blender-v1.png`.
The `.blend` and authoring script are not bundled into the website.

## Rebuild

Use Blender 4.5 LTS or a compatible version:

```text
blender --background --python build_garden.py -- --output garden-v1 --samples 512 --size 1536
```

Blender 4.5.9 LTS was downloaded from the official Blender release directory and
its SHA-256 was checked against the published checksum. The portable executable
is retained outside the repository under `release-work/tools/blender/`.

The scene renders with Cycles. CUDA is selected when available; otherwise it
uses the CPU. Denoising is disabled because it exceeded the available memory on
the authoring laptop. A 512-sample render supplies the finished image directly.

## Presentation

This is a rendered **environment**, with Leonidas's existing canonical portrait
shown separately as the speaker. It does not introduce a rigged 3D character.
Only the first chapter changes in this pilot. Dialogue, learning choices,
narration, notes and progress behavior retain their existing contracts.

The app applies a restrained 18-second push/pull to the rendered scene. A pause
control, the system reduced-motion preference, background state, and hidden-route
state stop motion. If the scene cannot load, the previous portrait presentation
is available as the fallback.

The local review build is separate from the member release. Publishing to
`leoinvesting.com` still requires access to its Cloudflare hosting account.
