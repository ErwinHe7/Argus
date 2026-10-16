import { planFills, type Answer, type Facts, type FormField, type Missing } from './answers.ts';
import type { Job } from './jobs.ts';
import { PAGE_SCRIPT } from './page-script.ts';
import type { Profile } from './profile.ts';

/** The slice of the Puppeteer page API the agent uses. */
export interface AgentPage {
  goto(url: string, options: { waitUntil: 'networkidle2'; timeout: number }): Promise<unknown>;
  evaluate(expression: string): Promise<unknown>;
  click(selector: string): Promise<void>;
  keyboard: { type(text: string, options?: { delay?: number }): Promise<void>; press(key: 'Enter'): Promise<void> };
  screenshot(options: { type: 'jpeg'; quality: number; fullPage: boolean; encoding: 'base64' }): Promise<unknown>;
  url(): string;
}

export interface ApplyInput {
  job: Job;
  profile: Profile;
  facts: Facts;
  resume: { name: string; base64: string };
  submit: boolean;
  onSubmissionAttempt?: () => Promise<void>;
}

export interface ApplyResult {
  status: 'submitted' | 'dry_run' | 'needs_you' | 'failed';
  message: string;
  missing: Missing[];
  screenshot: string | null;
  submissionAttempted?: boolean;
}

export type Answerer = (fields: FormField[], pageText: string) => Promise<Answer[]>;

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

function call<T>(page: AgentPage, name: string, ...args: unknown[]): Promise<T> {
  return page.evaluate(`window.__ap.${name}(${args.map(a => JSON.stringify(a)).join(',')})`) as Promise<T>;
}

async function screenshot(page: AgentPage, fullPage: boolean): Promise<string | null> {
  try {
    const data = await page.screenshot({ type: 'jpeg', quality: 45, fullPage, encoding: 'base64' });
    return typeof data === 'string' ? `data:image/jpeg;base64,${data}` : null;
  } catch {
    return null;
  }
}

/**
 * Opens the hosted application form, fills it from Claude's checked answers,
 * and submits only when every required field is answered and no CAPTCHA shows.
 */
export async function runApplication(page: AgentPage, input: ApplyInput, answer: Answerer): Promise<ApplyResult> {
  let submissionAttempted = false;
  const needsYou = async (message: string, missing: Missing[] = []): Promise<ApplyResult> =>
    ({ status: 'needs_you', message, missing, screenshot: await screenshot(page, true), submissionAttempted });

  // Some single-page forms never go network-idle; look for the form regardless.
  await page.goto(input.job.applyUrl, { waitUntil: 'networkidle2', timeout: 30_000 }).catch(() => undefined);
  await page.evaluate(PAGE_SCRIPT);
  const fields = await call<FormField[]>(page, 'extract');
  const questions = fields.filter(f => f.type !== 'file');
  if (!questions.length) return needsYou('No application form was found on this page.');

  for (const field of questions) {
    if (field.type === 'combobox') field.options = await call<string[]>(page, 'comboOptions', field.id);
  }
  const files = fields.filter(f => f.type === 'file');
  const resumeField = files.find(f => /resume|cv/i.test(f.label)) ?? files[0];
  const missing: Missing[] = [];
  if (resumeField && !(await call<boolean>(page, 'attach', resumeField.id, input.resume.name, input.resume.base64))) {
    missing.push({ label: resumeField.label, note: 'The resume upload did not take.' });
  }
  for (const file of files) {
    if (file !== resumeField && file.required) missing.push({ label: file.label, note: 'This form requires another file upload.' });
  }

  const answers = await answer(questions, await call<string>(page, 'pageText'));
  const plan = planFills(questions, answers);
  missing.push(...plan.missing);
  const failed = new Set(await call<string[]>(page, 'fill', plan.fills));
  for (const fill of plan.fills.filter(f => f.type === 'combobox')) {
    await page.click(`[data-ap-id="${fill.id}"]`);
    await page.keyboard.type(fill.values[0], { delay: 15 });
    await sleep(800);
    if (!(await call<string | null>(page, 'pick', fill.id, fill.values[0]))) {
      const field = questions.find(field => field.id === fill.id);
      // Enter can implicitly submit a native form, including during a dry run.
      // Only selecting an actual menu option completes a combobox answer.
      missing.push({ label: field?.label || fill.id, note: 'The agent could not select an option for this field.' });
    }
  }
  for (const field of questions) {
    if (failed.has(field.id)) missing.push({ label: field.label, note: 'The agent could not fill this field.' });
  }

  if (missing.length) return needsYou(`${missing.length} required item(s) need your input. Nothing was submitted.`, missing);
  if (!input.submit) {
    return { status: 'dry_run', message: `Filled ${plan.fills.length} fields. Dry run: nothing was submitted.`, missing, screenshot: await screenshot(page, true) };
  }
  if (await call<boolean>(page, 'captcha')) return needsYou('This form shows a CAPTCHA, so the agent stopped. Finish it yourself.');
  if (!(await call<boolean>(page, 'markSubmit'))) return needsYou('The submit button was not found.');

  const startUrl = page.url();
  // Record uncertainty before the click, so a worker interruption cannot silently retry it.
  await input.onSubmissionAttempt?.();
  submissionAttempted = true;
  await page.click('[data-ap-submit="1"]');
  for (let second = 1; second <= 20; second++) {
    await sleep(1000);
    let state: { confirmed: boolean; formGone: boolean; captcha: boolean; errors: string[] };
    try {
      await page.evaluate(PAGE_SCRIPT);
      state = await call(page, 'outcome');
    } catch {
      continue; // The page is mid-navigation.
    }
    const moved = page.url() !== startUrl;
    if (state.confirmed && (state.formGone || moved)) {
      return { status: 'submitted', message: 'Application submitted.', missing, screenshot: await screenshot(page, false), submissionAttempted: true };
    }
    if (state.captcha) return needsYou('A CAPTCHA appeared after submitting. Finish it yourself.');
    if (state.errors.length && !moved && second >= 3) return needsYou(`The form reported: ${state.errors.join(' | ')}`);
  }
  return needsYou('The agent clicked submit but could not confirm the application went through. Check the screenshot.');
}
