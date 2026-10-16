# Interview Scout

A website on Cloudflare Workers that saves your application and applies to jobs
for you in the background:

1. **Your saved application.** Enter the site access code and open your private
   workspace. Drop in a PDF; it is saved before Gemini reads it into a profile
   you can correct. You can also enter your profile manually.
2. **Who you are.** Add the facts application forms ask for: work
   authorization, sponsorship, start date, salary, voluntary self-identification
   preference, and so on.
3. **What you're hunting.** Search the public job boards on **Greenhouse,
   Lever and Ashby** by title, location and excluded words, or paste job links
   from those three sites.
4. **The hunt.** Save your details, pick jobs, and authorize the selected
   applications before pressing **Start the hunt**. A Cloudflare Workflow
   works through them one by one on the server, so you can close the tab. For
   each job, a headless Chrome (Cloudflare Browser Rendering):
   - opens the hosted application form and uploads the resume;
   - asks Gemini to answer every field from your resume and facts;
   - checks the answers against the form, fills it in and submits it.

   In the page, every job is a star in the night sky, and each one lights up
   when its application goes in. The hero art is the Big Dipper's pointer
   stars leading to Polaris, the North Star scouts steer by.

If a required question cannot be answered from your resume and stated facts,
the agent stops before submitting and marks the job **Needs you**. Add the
missing answer under "Anything else forms ask" and try again. If submit was
already clicked and the outcome is uncertain, check the employer's form before
taking further action: that job remains blocked from automatic resubmission.
Queued, active, submitted, and uncertain real applications are protected against
duplicate submissions within the same workspace. Dry runs remain repeatable.

Results and previous runs appear on this website. **Email notifications are not
connected yet.** The contact email in your profile is the address employers see.

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
  your Gemini and Cloudflare credit, so share it only with people you trust.

## Where data lives

| Data | Where | How long |
| --- | --- | --- |
| Profile, facts, search preferences, saved jobs | Private Cloudflare D1 database (`DB`) | Until you choose **Delete saved data** |
| Hunt metadata, authorization timestamps, application results | Private Cloudflare D1 database (`DB`) | Until you choose **Delete saved data** |
| Saved resume PDF, including replaced versions | Private Workers KV (`HUNTS`) | Until you choose **Delete saved data** |
| Resume and answers for a running hunt | Workers KV (`hunt:<id>:input`) | Deleted when the hunt ends or you press Stop; 7-day expiry as a backstop |
| Form screenshots | Private Workers KV | Up to 30 days, or until you delete saved data |
| Workspace recovery key and site access code | Your browser (localStorage) | Until browser storage is cleared |

The browser keeps a random private workspace key; the database stores only its
SHA-256 hash as the owner identifier. The site access code alone does not open
another person's workspace. API requests require both credentials, and hunt
history and screenshots are checked against that workspace.

Use **Copy recovery key** before changing devices or clearing browser storage.
On another browser, enter the site access code, choose **Use recovery key**, and
paste the saved key. Treat it as a password. This release has no email login or
email-based workspace recovery; losing the key removes your ability to reopen
that workspace through the website.

**Delete saved data** stops running scouts and removes that workspace's saved
profile, PDFs, preferences, jobs, history, and screenshots. It cannot withdraw
applications already delivered to employers. Old unowned KV hunts are not
imported into the new private workspace history. Existing browser drafts can be
reviewed and explicitly saved online when the workspace opens.

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
- A Google Gemini API key (free tier) from https://aistudio.google.com/apikey.
- An access code: any long random password you choose.

The configured account already has the `HUNTS` KV namespace and the
`interview-scout` D1 database. On a different account, create those resources and
replace their IDs in `wrangler.jsonc` before deploying. Keep the binding names
`HUNTS` and `DB`. The deploy registers the Workflow; database migrations must be
applied before the new Worker serves requests.

### Automatic (CI/CD)

The `interview-scout` GitHub Actions workflow has two paths:
- **Pull requests:** typecheck, test, and a bundle check.
- **Merges to `main`** (or a manual run from the Actions tab): the same
  checks, then a deploy that uploads the Worker secrets with it, then a check
  that the live site answers.

Add these repository secrets (Settings → Secrets and variables → Actions). The
two Cloudflare secrets are enough to deploy and apply the D1 migrations. Set
`INTERVIEW_SCOUT_ACCESS_CODE` to open and save workspaces. `GEMINI_API_KEY` is
required for automatic resume reading and application preparation; storage and
manual profile editing remain available without it. Add the secrets and run the
workflow again from the Actions tab.

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | A Cloudflare API token with Workers Scripts, Workers KV, Workflows, and **Account → D1 → Edit** access for the deployment account; ensure D1 Edit is included even when starting from the Workers template |
| `CLOUDFLARE_ACCOUNT_ID` | The Cloudflare account ID |
| `GEMINI_API_KEY` | A Google Gemini API key (free at aistudio.google.com/apikey) |
| `INTERVIEW_SCOUT_ACCESS_CODE` | The access code |

Optional repository variable: `CUSTOM_DOMAIN` (see **Domain**).
The deployment workflow runs `wrangler d1 migrations apply interview-scout
--remote` before publishing. See Cloudflare's
[migration documentation](https://developers.cloudflare.com/d1/reference/migrations/)
and [API permissions](https://developers.cloudflare.com/fundamentals/api/reference/permissions/).

### By hand

```bash
cd interview-scout
npm ci
npx wrangler login
npx wrangler d1 migrations apply interview-scout --remote
npx wrangler deploy
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put ACCESS_CODE
```

For a new account, after logging in and before applying migrations, create the
resources once and copy the returned IDs into `wrangler.jsonc`:

```bash
npx wrangler kv namespace create HUNTS
npx wrangler d1 create interview-scout
```

## Cost

Gemini is called once per resume upload and once per application. The model is
set by `GEMINI_MODEL` in `wrangler.jsonc`, defaulting to `gemini-3.5-flash-lite`.
This model supports PDF input and structured JSON and is available to new
projects; older 2.5 models may require prior project usage.
- **Gemini:** standard requests have a free tier, with project/model-specific
  quotas. Free-tier exhaustion returns an error; this app does not enable
  billing or switch to a paid model. Each application sends the resume plus
  the form and gets structured JSON back.
- **Browser Rendering:** billed by browser time, about one to two minutes per
  application. See Cloudflare's Browser Rendering pricing.
- **Fails closed:** if Gemini declines or returns an answer that doesn't match
  the expected shape, the job is reported rather than submitted with a guess.
  Requests time out after 20 seconds and provider responses are not included
  in application errors or logs.

Google's unpaid Gemini terms allow submitted content to be used for product
improvement and say not to submit personal, confidential, or sensitive
information. Use fictional or anonymized inputs for free-tier testing. Before
accepting real applicants' resumes, choose suitable data-handling terms and
make the provider disclosure explicit. See
[Gemini terms](https://ai.google.dev/gemini-api/terms).

## Develop

```bash
npm ci
npx wrangler d1 migrations apply interview-scout --local
npm run typecheck
npm test          # unit/SQLite tests, the hunt loop, and headless-Chrome fixture runs
npm run dev       # local server; put ACCESS_CODE and GEMINI_API_KEY in .dev.vars
```

Use Node 22 or newer; the storage tests use its SQLite module with a disposable
in-memory database. Local D1 and KV state are separate from the remote database.
The browser tests need Chrome or Chromium. Set `CHROME_PATH` if it isn't at the
default path in `test/apply.test.ts`.

| File | Purpose |
| --- | --- |
| `src/index.ts` | API routes, access-code check, request validation |
| `src/hunt.ts` | The hunt loop, status transitions, and submission-attempt recording |
| `src/applications/store.ts` | Private D1 intake/history, atomic duplicate reservations, and KV file storage |
| `src/applications/validation.ts` | Workspace credentials, bounded intake requests, canonical job URLs, and consent validation |
| `migrations/` | Versioned D1 database schema |
| `src/hunt-workflow.ts` | The Cloudflare Workflow that runs a hunt in a browser |
| `src/apply.ts` | Filling one application: open, fill, submit, confirm |
| `src/page-script.ts` | Code that runs inside the application page |
| `src/answers.ts` | Gemini's form answers and the checks before filling |
| `src/profile.ts` | Resume → profile with Gemini |
| `src/llm.ts` | The Gemini request helper (structured output, fails closed) |
| `src/jobs.ts`, `src/companies.ts` | Job board search, filtering, pasted links |
| `public/` | The website; `sky.js` draws the starfield, the North Star art and the hunt sky |
