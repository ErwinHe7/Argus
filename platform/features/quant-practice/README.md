# Quant practice

LEO's `/#/learn` is an independent chapter companion to Xinfeng Zhou's
*A Practical Guide to Quantitative Finance Interviews*. All seven chapters are
available from the start. `/#/learn?chapter=2` opens Brain Teasers.

| Chapter | Playable lab | Original exercises |
| --- | --- | --- |
| 1 · General Principles | Order an interview reasoning ladder | 8 |
| 2 · Brain Teasers | Transform a chameleon population and prove an invariant | 9 |
| 3 · Calculus and Linear Algebra | Predict eigenvector transformations | 9 |
| 4 · Probability Theory | Update a bag-selection belief using evidence and priors | 8 |
| 5 · Stochastic Processes and Calculus | Explore a two-day Markov chain | 8 |
| 6 · Finance | Match call, straddle and spread payoff shapes | 8 |
| 7 · Algorithms and Numerical Methods | Find a target by halving a search range | 8 |

Labs are untimed. Practice offers an optional, manually started 90-second clock,
two progressive hints, answer checking and worked explanations. Mistakes and
help-assisted questions enter review. Correct answers following a miss remain
marked for another attempt. Reviewing a solution alone never counts as exercise
completion. A later independent pass clears its review flag; activity counts
are not certification of mastery or interview readiness.

## Data and state

`content.py` exports the deterministic 58-exercise `content.json`. All 41 numeric
reference answers are computed offline in Python. `content.ts` validates the
artifact before use. Fixed fictional lab fixtures live in `labs-state.ts`.
The browser checks submitted answers, renders diagrams, and updates toy game
state; it performs no production inference or market calculation. No exchange,
account, LLM service, order or live-data dependency is introduced.

The exercise wording, hints, and explanations are original. Only chapter/topic
structure is mapped to the book, using the linked library catalogue in artifact
provenance. These exercises supplement the book's full treatment.

Progress is stored under `leo.quant-practice.v1` in this origin's localStorage.
It remains separate from LEO identity. Export and import merge progress by newest
exercise timestamp, retaining the union of completed lab identifiers. Imports
reject oversized data, unknown questions, invalid counts, and malformed records.
Storage failure leaves a usable session and a visible export reminder. Clearing
progress requires an explicit inline confirmation; existing unrelated storage
keys are untouched.

## Checks and rebuild

From `platform/`:

```powershell
python features/quant-practice/content.py
python -m unittest discover -s features/quant-practice -p test_content.py -v
node --import tsx --test features/quant-practice/*.test.ts
node node_modules/typescript/bin/tsc --noEmit -p features/research-desk/tsconfig.json
node --import tsx scripts/research-desk-build.mjs
```

The Python tests independently enumerate counting/conditioning examples, check
every numeric reference, verify a replicating portfolio, and test variance,
Markov boundaries and numerical conventions. TypeScript tests validate malformed
content and imports, review semantics, numeric parsing, game invariants, binary
search narrowing, and accessible payoff samples.

Browser checks exercise all seven labs, chapter selection, hints, wrong/correct
feedback, review, optional timing, reload persistence, export/import, native
disclosures, keyboard use and phone layout. Payoff curves expose both shape
descriptions and a table. See [SURFACE.md](SURFACE.md) for visual authority and
bounded review evidence.

## Release

Use `scripts/quant-practice-stage.py` to overlay **only** `desk.js` and `desk.css`
on a manifest-verified current frozen release. It preserves model-atlas data,
Jev assets, public configuration, all backend files, existing domains and bindings.
Do not rebuild or replace the retained Next.js backend for this UI addition.

After dry-run and deployment, run `scripts/quant-practice-live-verify.mjs` against
the finalized stage. The verifier checks eight asset hashes and nine retained
routes on workers.dev and both custom domains. Record the Worker version and
previous version in the release receipt.
