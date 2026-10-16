import puppeteer from '@cloudflare/puppeteer';
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from 'cloudflare:workers';
import { answerFields } from './answers.ts';
import { runApplication, type AgentPage, type ApplyResult } from './apply.ts';
import { runHunt, type HuntInput, type Steps } from './hunt.ts';
import { databaseHuntStore } from './applications/store.ts';
import type { Job } from './jobs.ts';

async function applyOne(env: Env, input: HuntInput, job: Job, onSubmissionAttempt: () => Promise<void>): Promise<ApplyResult> {
  let submissionAttempted = false;
  try {
    const browser = await puppeteer.launch(env.BROWSER);
    try {
      const page = await browser.newPage();
      await page.setViewport({ width: 1280, height: 1000 });
      return await runApplication(page as unknown as AgentPage, { ...input, job, onSubmissionAttempt: async () => {
        await onSubmissionAttempt();
        submissionAttempted = true;
      } }, (fields, pageText) => answerFields(env, {
        resumeBase64: input.resume.base64, profile: input.profile, facts: input.facts,
        job: { company: job.company, title: job.title, url: job.url }, pageText, fields,
      }));
    } finally {
      await browser.close();
    }
  } catch (error) {
    return { status: submissionAttempted ? 'needs_you' : 'failed', message: submissionAttempted ? 'Submission was attempted, but confirmation was interrupted. Check the employer form before retrying.' : (error instanceof Error ? error.message.slice(0, 500) : 'The agent failed.'), missing: [], screenshot: null, submissionAttempted };
  }
}

export class HuntWorkflow extends WorkflowEntrypoint<Env, { huntId: string }> {
  async run(event: Readonly<WorkflowEvent<{ huntId: string }>>, step: WorkflowStep) {
    const store = databaseHuntStore(this.env.DB, this.env.HUNTS);
    try {
      return await runHunt(event.payload.huntId, step as unknown as Steps, {
        store,
        applyOne: (input, job, onSubmissionAttempt) => applyOne(this.env, input, job, onSubmissionAttempt),
      });
    } catch (error) {
      await store.setStatus(event.payload.huntId, 'errored');
      await store.deleteInput(event.payload.huntId);
      throw error;
    }
  }
}
