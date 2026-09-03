# Reveal choreography and voice — historical prototype

> **Superseded:** This browser prototype is no longer the canonical Daily Ritual. The production authority is the [Daily Ritual rebuild](../../../ritual-investing-app/docs/reviews/daily-ritual-rebuild.md) and its current in-place light/dark visual goldens.

## Question

Where should Leonidas enter the Daily Ritual, and when should his spoken interpretation begin?

## Prototype

- Comparison surface: `index.html`
- Tested in a portrait 390 × 844 mobile stage.
- Used real CSS motion, a browser-synthesized placeholder voice, captions, and an evidence sheet.

## Historical decision

Use a hybrid of directions A and B:

1. Leonidas begins as a full-body, standing presence and conducts the opening.
2. He summons and flips the card while still shown standing.
3. Only after the card face is visible does the camera transition to a close-up of Leonidas.
4. The close-up carries his spoken interpretation and the invitation to inspect evidence.

This preserves A's commanding, character-led entrance while giving B's spoken counsel a more intimate and earned visual treatment.

## Rejected as the canonical sequence

- Pure A: one full-body composition throughout the entire reading.
- Pure B: a silent card reveal before Leonidas appears at all.
- Pure C: alternating symbol, signal, and uncertainty layers as the primary choreography.

Direction C's progressive disclosure may still inform the evidence treatment, but it is not the canonical entrance-and-voice sequence.

## Required adjustments

- Keep the full-body-to-close-up transition readable on a phone without crowding the card.
- Begin the close-up only after the flip completes.
- Keep captions complete when voice is unavailable or disabled.
- Keep evidence, uncertainty, and the non-recommendation boundary explicit.

## Superseding production decision

- The invitation remains passive and navigable until **Start your daily ritual** is chosen.
- Start crossfades the seal into the existing Leonidas stage while the top controls and bottom navigation remain fixed. The member holds for five continuous seconds; releasing early cancels without revealing.
- The real assigned card and one interpretation appear after authoritative reveal. One explicit Finish precedes the short skippable Leonidas close and the Evidence → Starpath handoff.
- Leonidas remains visibly present throughout; the seal, card, and copy preserve the face-clear zone. No finger, sensor, or biometric metaphor appears in the UI.
- Ordinary-size ceremony states do not scroll. Accessibility scaling may adapt the lower content region so complete strings and controls remain reachable.
- Native iOS/Android speech remains optional presentation with complete captions, Reduced Motion, assistive semantic activation, interruption handling, and fail-closed mutation behavior.

The earlier standing → flip → close-up choreography and its post-reading content stack remain useful exploration history only. They must not be restored as product guidance or regression authority.
