import puppeteer from '@cloudflare/puppeteer';
import { WorkflowEntrypoint, type WorkflowEvent, type WorkflowStep } from 'cloudflare:workers';
import { answerFields } from './answers.ts';
import { runApplication, type AgentPage, type ApplyResult } from './apply.ts';
import { kvStore, runHunt, type HuntInput, type Steps } from './hunt.ts';
import type { Job } from './jobs.ts';

async function applyOne(env: Env, input: HuntInput, job: Job): Promise<ApplyResult> {
  try {
    const browser = await puppeteer.launch(env.BROWSER);
    try {
      const page = await browser.newPage();
      await page.setViewport({ width: 1280, height: 1000 });
      return await runApplication(page as unknown as AgentPage, { ...input, job }, (fields, pageText) => answerFields(env, {
        resumeBase64: input.resume.base64, profile: input.profile, facts: input.facts,
        job: { company: job.company, title: job.title, url: job.url }, pageText, fields,
      }));
    } finally {
      await browser.close();
    }
  } catch (error) {
    return { status: 'failed', message: error instanceof Error ? error.message : 'The agent failed.', missing: [], screenshot: null };
  }
}

export class HuntWorkflow extends WorkflowEntrypoint<Env, { huntId: string }> {
  async run(event: Readonly<WorkflowEvent<{ huntId: string }>>, step: WorkflowStep) {
    return runHunt(event.payload.huntId, step as unknown as Steps, {
      store: kvStore(this.env.HUNTS),
      applyOne: (input, job) => applyOne(this.env, input, job),
    });
  }
}
