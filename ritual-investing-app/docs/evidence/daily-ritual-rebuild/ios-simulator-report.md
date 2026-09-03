# Daily Ritual iOS simulator report

**Date:** 2026-09-02  
**Branch:** `codex/daily-ritual-rebuild`  
**Revision under test:** `903e3f2` plus the final U6 review fixes, captures, goldens, and documentation recorded by this report  
**Reference viewport:** 402×874 logical pixels, portrait  
**Visual authority:** [Approved fullscreen contact sheet](g1-fullscreen-approved-contact-sheet.jpg)  
**Detailed geometry:** [Approved layout specification](layout-spec.md)

## Xcode Test Results

**Project:** `ios/Runner.xcworkspace`  
**Scheme:** `Runner`  
**Simulator:** iPhone 17, iOS 26.5 (`E13228D5-C858-430D-9BEB-99ADA5607450`)  
**Build:** Success  
**Screens tested:** 7

| Screen or flow | Status | Evidence / notes |
|---|---|---|
| Assigned invitation and explicit Start | PASS | [`01-resting.png`](simulator/iphone-17/01-resting.png). Invitation remains inside the app shell; no ritual begins until Start. |
| Fullscreen hold at 60% | PASS | [`02-holding-60.png`](simulator/iphone-17/02-holding-60.png). No app header, bottom navigation, finger/cursor, or face overlap; ring and copy report 3 of 5 seconds. |
| Authoritative reveal | PASS | [`03-revealed.png`](simulator/iphone-17/03-revealed.png). Actual Emperor art, one interpretation, and one Finish action render without chrome or layout breakage. |
| Server-confirmed C2 close | PASS | [`04-c2-closing.png`](simulator/iphone-17/04-c2-closing.png). The same art expands below Leonidas's face; complete caption and Skip remain available. |
| Completed onward handoff | PASS | [`05-completed-onward.png`](simulator/iphone-17/05-completed-onward.png). Keepsake art, interpretation, Evidence, and Starpath fit without ordinary-size scrolling. |
| Evidence and return | PASS | Final iPhone integration run opened the production Evidence sheet, found its semantic Done control, dismissed it, and verified return to Completed fullscreen. |
| Continue to Starpath | PASS | Final iPhone integration run tapped Starpath, verified fullscreen dismissal, restored shell navigation, and observed the handoff callback exactly once. |
| Face-clear geometry and art continuity | PASS | Measured stage tests enforce the reference rectangles to ±0.1 point, exceeding the ±4-point review tolerance. Product review confirmed the same Emperor art and unobstructed face across the five captured frames. |
| Early release, exact 5.000 s, slow/error/retry, interruption, restoration, and fail-closed authority | PASS | Deterministic controller, widget, cache, lifecycle, offline, and integration tests pass. These behavioral permutations reuse the approved stage and intentionally do not duplicate image-heavy baselines. |
| Voice off/interrupted, semantic activation, Reduced Motion, and 2× text | PASS | Accessibility and sequence tests pass; the native capture uses the accessibility-only **Begin ritual** action and produces no synthetic touch marker. Ordinary-size scrolling is absent; accessibility-only reflow remains available. |
| Supported portrait adaptation | PASS | Reference goldens run at 402×874; focused layout/accessibility coverage also passes at 390×844 and 430×932. |

**Console errors:** 0 flow-attributable crashes, uncaught exceptions, or failed fixture requests. The sanitized record is [`logs/iphone-17.log`](logs/iphone-17.log).  
**Human verifications:** 1 — the product owner approved the five post-refinement iPhone 17 production frames on 2026-09-02.  
**Failures:** 0 residual Daily Ritual failures.  
**Result:** PASS

## Verification commands

- XcodeBuildMCP build, install, and launch — PASS.
- `flutter drive --no-pub --driver=test_driver/daily_ritual_capture.dart --target=integration_test/daily_ritual_g1_capture_test.dart -d E13228D5-C858-430D-9BEB-99ADA5607450` — PASS, `2/2` integration phases.
- `flutter test --no-pub --reporter compact test/visual_reference_test.dart` — PASS, `2/2` journeys and ten approved snapshot comparisons.
- `flutter test --no-pub --reporter compact --exclude-tags golden` — PASS, `515/515` tests.
- `flutter analyze --no-pub` — PASS.

## Review notes and residuals

- Generated probes remain composition references only. Real product assets, copy, accessibility, and state authority take precedence.
- The earlier probe comparison is retained once as [`g1-probe-comparison.jpg`](g1-probe-comparison.jpg). Because the fullscreen refinement preserves the same measured 370×632 stage and changes only its shell boundary, a second set of duplicate side-by-side, overlay, and heatmap files was intentionally not retained.
- The completion heading stays in the top-left metadata area; the probe's centered position would violate the face-clear zone.
- Flutter emits a non-failing warning because the repository's `dart_test.yaml` does not declare the existing `golden` tag. It does not affect discovery or results and is outside this feature change.
- Flutter also reports removable legacy CocoaPods integration even though current plugins use Swift Packages. No migration was performed because it is unrelated to this feature and did not affect the iOS build.
- Attunement animation polish is intentionally deferred. The current motion is production-safe and meets timing, cancellation, Reduced Motion, and no-fake-sensor requirements.
- The final Compound Engineering review completed. Its cache-validity, fail-closed media, visibility acknowledgement, controller-authority, and image-error coverage findings were applied and retested; no actionable Daily Ritual finding remains.

## Post-Deploy Monitoring & Validation

- **Window and owner:** Release owner checks the first 72 hours after rollout; product owner reviews the first complete real-device ritual session.
- **Healthy signals:** Stable Daily Ritual crash-free sessions; normal current-assignment GET traffic; one reveal and one complete transition at most per completed assignment; no sustained increase in retry, conflict, or media-unavailable surfaces.
- **Logs to inspect:** Existing Ritual API request logs for current-assignment, reveal, and complete routes; status codes, `If-Match` conflicts, idempotency reuse, latency, and assignment/version mismatches. Do not log member content or cache scope identifiers.
- **Failure signals:** Repeated reveal/complete ambiguity, elevated conflict or 5xx rates, card-asset decode failures, route/lifecycle exceptions, or reports that the hold reveals early, fails to cancel, repeats C2, or shows app chrome in fullscreen.
- **Mitigation trigger:** Pause rollout or return to the prior app release when lifecycle authority can diverge, concealed content leaks, or crashes/layout failures are reproducible. Isolated content/media failures remain fail-closed while the exact assignment is investigated.
