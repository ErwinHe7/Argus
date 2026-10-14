# Job Autopilot

A small website on Cloudflare Workers that applies to jobs for you:

1. Upload a PDF resume. Claude reads it into a profile you can correct.
2. Add the facts application forms ask for (work authorization, sponsorship,
   start date, salary, voluntary self-identification preference…).
3. Search public job boards on **Greenhouse, Lever and Ashby** by title,
   location and excluded words, or paste job links from those three sites.
4. Pick jobs and press **Start applying**. For each job, a headless Chrome
   (Cloudflare Browser Rendering) opens the hosted application form, uploads
   the resume, asks Claude to answer every field from your resume and facts,
   checks the answers against the form, fills it in and submits it.

It never makes things up. If a required question cannot be answered truthfully
from what you gave it, the job is marked **Needs you** with the question listed,
and nothing is submitted. Add the answer to "Other facts" and run it again.

## What to expect

- **Start with a dry run.** Leave "Submit for real" unticked: the agent fills
  each form and shows a screenshot without submitting. Check a few, then turn
  on real submission.
- **CAPTCHAs and bot checks are handed back to you.** The agent does not try to
  get around them. Those jobs are marked **Needs you** with a link to the form.
- **Only Greenhouse, Lever and Ashby.** Workday, iCIMS, Taleo, LinkedIn Easy
  Apply and company-built forms are not supported.
- The form filler was tested against local copies of those form styles, not
  the live sites. If a site changes its markup, the result is **Needs you**
  rather than a wrong submission.
- Your resume and answers stay in your browser (localStorage). The server only
  sees them while a request runs and stores nothing.
- Anyone with the access code spends your Claude and Cloudflare credit. Share it
  only with people you trust.

## Deploy (one time)

You need:

- A Cloudflare account on the **Workers Paid** plan ($5/month). The free plan's
  CPU and Browser Rendering limits are too small for this.
- An Anthropic API key from https://console.anthropic.com.
- An access code: any long random password you choose.

### Option A: from your computer

```bash
cd job-autopilot
npm ci
npx wrangler login
npx wrangler deploy                       # prints https://job-autopilot.<subdomain>.workers.dev
npx wrangler secret put ANTHROPIC_API_KEY # paste the key
npx wrangler secret put ACCESS_CODE       # paste the access code
```

### Option B: from GitHub Actions

After this folder is on the default branch, add these repository secrets
(Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token from the "Edit Cloudflare Workers" template |
| `CLOUDFLARE_ACCOUNT_ID` | Your Cloudflare account ID |
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `JOB_AUTOPILOT_ACCESS_CODE` | The access code |

Then run the **job-autopilot** workflow from the Actions tab.

Either way the site is served at `https://job-autopilot.<your-subdomain>.workers.dev`.
If the account has no workers.dev subdomain yet, open Workers & Pages in the
Cloudflare dashboard once to create it.

## Cost

Claude is called once per resume upload and once per application. The model is
set by `CLAUDE_MODEL` in `wrangler.jsonc` (default `claude-opus-5-5`). As a rough
estimate, one application sends the resume plus the form (a few thousand input
tokens) and gets back a few thousand output tokens, a few cents per application.
Browser Rendering is billed by browser time, about one to two minutes per
application; see Cloudflare's Browser Rendering pricing. If Claude declines a
request on safety grounds, the API reruns it on Anthropic's recommended
fallback model (`fallbacks: "default"`).

## Develop

```bash
npm ci
npm run typecheck
npm test          # unit tests plus headless-Chrome runs against test/fixtures
npm run dev       # local server; put ACCESS_CODE and ANTHROPIC_API_KEY in .dev.vars
```

The browser tests need Chrome or Chromium. Set `CHROME_PATH` if it is not at the
default path in `test/apply.test.ts`.

| File | Purpose |
| --- | --- |
| `src/index.ts` | API routes, access-code check, request validation |
| `src/profile.ts` | Resume → profile with Claude |
| `src/jobs.ts`, `src/companies.ts` | Job board search, filtering, pasted links |
| `src/answers.ts` | Claude's form answers and the checks before filling |
| `src/apply.ts` | The browser agent: open, fill, submit, confirm |
| `src/page-script.ts` | Code that runs inside the application page |
| `public/` | The website |
