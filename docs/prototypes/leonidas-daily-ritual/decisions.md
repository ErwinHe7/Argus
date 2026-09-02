# Reveal choreography and voice

## Question

Where should Leonidas enter the Daily Ritual, and when should his spoken interpretation begin?

## Prototype

- Comparison surface: `screens/001-comparison.html`
- Tested in a portrait 390 × 844 mobile stage.
- Used real CSS motion, a browser-synthesized placeholder voice, captions, and an evidence sheet.

## Decision

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

## Open production items

- Final Leonidas voice casting and speech system.
- Production-grade transition timing and motion assets.
- Mapping reviewed Daily Ritual output into the spoken script.
- Accessibility behavior for reduced motion, VoiceOver/TalkBack, and interrupted audio.
