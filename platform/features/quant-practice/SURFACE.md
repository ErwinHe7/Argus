# Quant practice

Mode: Operate / Read. A chapter companion to Xinfeng Zhou's Green Book, inside
the existing LEO workspace. Exercises are original examples mapped to the book's
seven chapter topics; the app does not reproduce the book. `/#/learn` is a
supporting learning route. The research-desk DESIGN.md and existing surface
sidecars retain authority over the shared workspace and other routes.

## Direction contract

THESIS: Strengthen understanding through a playable experiment, a reasoned
answer, progressive hints, and a worked explanation for every chapter.

OWN-WORLD: Inherit LEO's aubergine working field, candle-gold actions, lilac
diagrams, Inter typography, fine rules, Lion brand, and native disclosures.

STORY: Choose a chapter, play its lab, practise its concepts, then revisit
mistakes. All seven chapters remain open. Labs are untimed; practice offers an
optional, manually started clock.

FIRST VIEWPORT: A compact title and progress line above a two-column syllabus
and working lab. The selected chapter and actual activity lead. Mobile replaces
the syllabus with a labelled chapter selector so the activity stays near the top.

FORM: A local learning extension within the established LEO world. A persistent
chapter rail and task tabs replace an undifferentiated wall of quiz cards.

FINISH: Record the implemented behavior, bounded finish-review verdict, checks,
and actual capture coverage here and in research-desk DESIGN.md. No new raster
asset or shared design token is introduced by this extension.

## Implemented flow

The seven labs cover a reasoning ladder, chameleon invariant, eigenvector
directions, Bayesian updates, a two-day Markov chain, payoff matching, and binary
search. The chapter rail remains visible on desktop; at 760px and below, a
labelled native select replaces it. Play the lab, Practise concepts, and Review
controls select the working activity. The title is 36px on desktop and 28px at
the mobile breakpoint, within the incumbent Inter hierarchy.

The 58 original exercises provide answer checks, two progressive hints, and
worked explanations. The 90-second challenge option starts enabled, but its
countdown starts only after Start 90-second timer. Turning it off removes the
clock; expiry leaves the exercise usable. A miss, hint, or solution exposure
marks an exercise for review. A subsequent assisted correct answer keeps that
flag; a later independent pass clears it. Reading a solution alone does not
complete an exercise.

Native controls, visible gold focus, labelled inputs, pressed/current states,
and status feedback support keyboard operation. Vector diagrams have textual
descriptions. Payoff choices expose shape descriptions plus a native table of
sample values; the Markov probabilities also use a native table. Reduced-motion
preferences disable scoped transitions. These are component treatments within
the existing aubergine, gold, lilac, fine-rule system, not a new visual world.

## Behavior and boundaries

All 41 numeric reference answers are computed offline in Python. The browser
validates the exported content, checks answers, renders diagrams, and manages
fixed fictional lab state. No market observations, production model inference,
account service, or execution is involved.

Progress stays in this origin's localStorage, separately from LEO identity, with
export and import/merge controls. Newer exercise timestamps win overlaps; completed
lab identifiers are retained as a union. Invalid or oversized imports are
rejected. Storage failure leaves the session usable with an export reminder;
clearing progress requires an inline confirmation. Completion describes practice
activity, not certified mastery or interview readiness. Content and rebuild
details remain in [README.md](README.md).

## Verification and finish review · October 22, 2026

Final verdict: **ship** for the inspected source and captured interface states.
The independent reviewer reported no material findings within that scope. This
does not independently attest the numeric run, full browser workflow, deployment,
or retained routes.

The implementation owner reports all seven labs exercised; all 41 numeric
references checked in Python; 16 feature TypeScript tests and six retained tests
passing; scoped TypeScript and static-build checks passing; and browser checks
for wrong answers, hints, correct answers, review, optional manual timing, reload
persistence, and export/import merge. DOM width checks at requested 1280×900 and
390×844 browser viewports found no page overflow. The mechanical detector
reported zero findings; it is separate from the independent finish review.

Review captures are in
`C:/Users/Hj/Desktop/Leo Roar/release-work/leo-quant-practice-20261022/`.
These existing evidence filenames are recorded with their decoded dimensions:

| Capture | Actual image size | State |
| --- | --- | --- |
| `practice-desktop.png` | 1270×893 | Desktop opening |
| `practice-mobile.png` | 380×822 | Mobile opening |
| `practice-game-mobile.png` | 390×843 | Mobile activity |
| `practice-payoffs.png` | 1270×893 | Payoff lab |
| `practice-solution-mobile.png` | 380×822 | Mobile worked solution |

The capture API cropped the requested viewport sizes. These images show the
listed states at their actual dimensions; they are not full-page proof.
Full-page capture was unsupported. The captures are review evidence, not new
shipping raster assets. Release and live-verification status belong to the
separate delivery receipts.
