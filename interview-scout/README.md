# Interview Scout

A website on Cloudflare Workers that applies to jobs for you, in the background:

1. **Your resume.** Drop in a PDF. Claude reads it into a profile you can correct.
2. **Who you are.** Add the facts application forms ask for: work
   authorization, sponsorship, start date, salary, voluntary self-identification
   preference, and so on.
3. **What you're hunting.** Search the public job boards on **Greenhouse,
   Lever and Ashby** by title, location and excluded words, or paste job links
   from those three sites.
4. **The hunt.** Pick jobs and press **Start the hunt**. A Cloudflare Workflow
   works through them one by one on the server, so you can close the tab. For
   each job, a headless Chrome (Cloudflare Browser Rendering):
   - opens the hosted application form and uploads the resume;
   - asks Claude to answer every field from your resume and facts;
   - checks the answers against the form, fills it in and submits it.

   In the page, every job is a star in the night sky, and each one lights up
   when its application goes in. The hero art is the Big Dipper's pointer
   stars leading to Polaris, the North Star scouts steer by.

It never makes things up. If a required question can't be answered truthfully
from what you gave it, the job is marked **Needs you** with that question
listed, and nothing is submitted. Add the answer under "Anything else forms ask"
and hunt again.

## What to expect

- **Start with a dry run.** Leave "Submit for real" off: the hunt fills each
  form and saves a screenshot without submitting. Check a few, then switch to
  real submissions.
- **CAPTCHAs and bot checks go back to you.** The agent doesn't try to get
  around them. Those jobs are marked **Needs you** and link to the form.
- **Only Greenhouse, Lever and Ashby.** Workday, iCIMS, Taleo, LinkedIn Easy
  Apply and company-built forms aren't supported.
- **Tested on local copies of those forms, not the live sites.** If a site
  changes its markup, you get **Needs you** rather than a wrong submission.
- **Each application takes one to two minutes.** A hunt applies to one job at a
  time and holds up to 400 jobs. At most two hunts run at once; others wait
  their turn.
- **Sharing the access code shares your bill.** Anyone with the code spends
  your Claude and Cloudflare credit, so share it only with people you trust.

## Where data lives

| Data | Where | How long |
| --- | --- | --- |
| Profile, facts, job list, results | Your browser (localStorage) | Until you clear it |
| Resume and answers for a running hunt | Workers KV (`hunt:<id>:input`) | Deleted when the hunt ends or you press Stop; 7-day expiry as a backstop |
| Hunt results and form screenshots | Workers KV | 30 days |

## Domain

- **Free, by default:** the Worker is named `interview-scout`, so every deploy
  serves it at `https://interview-scout.<account-subdomain>.workers.dev`. On the
  axio7 account that's `https://interview-scout.axio7.workers.dev`.
- **`interview-scout.dev` is not free.** `.dev` domains are sold by Google
  Registry, and no registrar gives them away. Cloudflare Registrar sells at
  cost, roughly $10–15 a year; check the price at checkout. To use it:
  1. In the same Cloudflare account, open **Domain Registration → Register
     Domains** and buy `interview-scout.dev`. It becomes a zone in that account
     automatically. If you buy it elsewhere, add it to Cloudflare and switch its
     nameservers instead.
  2. In GitHub, add a repository **variable** (not a secret): `CUSTOM_DOMAIN` =
     `interview-scout.dev www.interview-scout.dev`.
  3. The next deploy attaches both names with HTTPS. For a deploy by hand, add
     `--domain interview-scout.dev --domain www.interview-scout.dev`.

  If the deploy says the token lacks permission for the zone, give the API
  token **Zone → DNS → Edit** and **Zone → Workers Routes → Edit** for
  `interview-scout.dev`.
- Codex's older `interview-hunter` Worker is a separate Worker and is left
  untouched. Delete it in the dashboard if you no longer want it.

## Deploy

You need:
- A Cloudflare account on the **Workers Paid** plan. The free plan's CPU and
  Browser Rendering limits are too small for this.
- An Anthropic API key.
- An access code: any long random password you choose.

The first deploy creates the KV namespace and registers the Workflow on its
own.

### Automatic (CI/CD)

The `interview-scout` GitHub Actions workflow has two paths:
- **Pull requests:** typecheck, test, and a bundle check.
- **Merges to `main`** (or a manual run from the Actions tab): the same
  checks, then a deploy, then it sets the Worker secrets and checks that the
  live site answers.

Add these repository secrets once (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | A Cloudflare API token with Workers Scripts, Workers KV and Workflows edit access (the "Edit Cloudflare Workers" template covers it) |
| `CLOUDFLARE_ACCOUNT_ID` | The Cloudflare account ID |
| `ANTHROPIC_API_KEY` | The Anthropic API key |
| `INTERVIEW_SCOUT_ACCESS_CODE` | The access code |

Optional repository variable: `CUSTOM_DOMAIN` (see **Domain**).

### By hand

```bash
cd interview-scout
npm ci
npx wrangler login
npx wrangler deploy
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ACCESS_CODE
```

## Cost

Claude is called once per resume upload and once per application. The model is
set by `CLAUDE_MODEL` in `wrangler.jsonc`, defaulting to `claude-opus-5-5`.
- **Claude:** a rough estimate is a few cents per application. Each one sends
  the resume plus the form, a few thousand input tokens, and gets back a few
  thousand output tokens.
- **Browser Rendering:** billed by browser time, about one to two minutes per
  application. See Cloudflare's Browser Rendering pricing.
- **Fallback:** if Claude declines a request on safety grounds, the API reruns
  it on Anthropic's recommended fallback model (`fallbacks: "default"`).

## Develop

```bash
npm ci
npm run typecheck
npm test          # unit tests, the hunt loop, and headless-Chrome runs against test/fixtures
npm run dev       # local server; put ACCESS_CODE and ANTHROPIC_API_KEY in .dev.vars
```

The browser tests need Chrome or Chromium. Set `CHROME_PATH` if it isn't at the
default path in `test/apply.test.ts`.

| File | Purpose |
| --- | --- |
| `src/index.ts` | API routes, access-code check, request validation |
| `src/hunt.ts` | The hunt loop and its KV storage layout |
| `src/hunt-workflow.ts` | The Cloudflare Workflow that runs a hunt in a browser |
| `src/apply.ts` | Filling one application: open, fill, submit, confirm |
| `src/page-script.ts` | Code that runs inside the application page |
| `src/answers.ts` | Claude's form answers and the checks before filling |
| `src/profile.ts` | Resume → profile with Claude |
| `src/jobs.ts`, `src/companies.ts` | Job board search, filtering, pasted links |
| `public/` | The website; `sky.js` draws the starfield, the North Star art and the hunt sky |
