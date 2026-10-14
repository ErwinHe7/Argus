import { z } from 'zod';
import { askClaude, pdfBlock, type ClaudeEnv } from './claude.ts';
import type { Profile } from './profile.ts';

export type FieldType =
  | 'text' | 'email' | 'tel' | 'url' | 'number' | 'date' | 'textarea'
  | 'select' | 'radio' | 'checkbox' | 'checkbox-group' | 'combobox' | 'file';

/** A form control as reported by the in-page script. */
export interface FormField { id: string; type: FieldType; label: string; required: boolean; options: string[] }

export interface Fill { id: string; type: FieldType; values: string[] }
export interface Missing { label: string; note: string }

export interface Facts { workAuthorizedUS: string; needsSponsorship: string; notes: string }

const AnswersSchema = z.object({
  answers: z.array(z.object({ id: z.string(), values: z.array(z.string()), note: z.string() })),
});
export type Answer = z.infer<typeof AnswersSchema>['answers'][number];

const SYSTEM = `You fill out job application forms for a candidate who has asked you to apply on their behalf.
You get the candidate's resume, profile, and facts they stated, the job, and the form's fields as JSON.
Return one answer per field id.

Rules:
- Be truthful. Use only the resume, profile and facts. Never invent or embellish employers, titles, dates, degrees, grades, skills, numbers, legal status or demographic data.
- For a field with options, copy each value exactly from its options. Give several values only for type "checkbox-group".
- For type "checkbox", answer ["Yes"] to tick it or [] to leave it. Tick acknowledgements of the privacy notice, data processing, or that the application is accurate. Leave marketing and newsletter opt-ins unticked.
- Voluntary self-identification (gender, race, ethnicity, veteran, disability, sexual orientation): use the candidate's stated answer; otherwise pick the option that declines to answer.
- Open questions (cover letter, why this company, anything else to share): write a specific first-person answer under 120 words, grounded only in the resume and the job.
- Name, email, phone, location and links come from the profile; split the name when a field asks for first or last name.
- If you cannot answer a field truthfully from what you were given, return values [] and, in note, say in one short sentence what the candidate needs to tell you. Do this for required fields too; never guess.
- Leave note empty when you answered.`;

export async function answerFields(env: ClaudeEnv, input: {
  resumeBase64: string;
  profile: Profile;
  facts: Facts;
  job: { company: string; title: string; url: string };
  pageText: string;
  fields: FormField[];
}): Promise<Answer[]> {
  const { resumeBase64, fields, ...context } = input;
  const result = await askClaude(env, {
    system: SYSTEM,
    content: [
      pdfBlock(resumeBase64),
      { type: 'text', text: JSON.stringify({ ...context, fields: fields.map(({ id, type, label, required, options }) => ({ id, type, label, required, options })) }) },
    ],
    schema: AnswersSchema,
    effort: 'medium',
  });
  return result.answers;
}

const norm = (text: string) => text.replace(/\s+/g, ' ').trim().toLowerCase();
const CHOICE: FieldType[] = ['select', 'radio', 'checkbox-group', 'combobox'];

/**
 * Checks Claude's answers against the form before anything is typed: choice
 * answers must name a real option, and every required field needs an answer.
 */
export function planFills(fields: FormField[], answers: Answer[]): { fills: Fill[]; missing: Missing[] } {
  const byId = new Map(answers.map(a => [a.id, a]));
  const fills: Fill[] = [];
  const missing: Missing[] = [];
  for (const field of fields) {
    if (field.type === 'file') continue;
    const answer = byId.get(field.id);
    let values = (answer?.values ?? []).map(v => v.trim()).filter(Boolean);
    if (field.type === 'checkbox') {
      values = values.some(v => /^(yes|true|checked)$/i.test(v)) ? ['Yes'] : [];
    } else if (CHOICE.includes(field.type) && field.options.length) {
      values = [...new Set(values.map(v => field.options.find(o => norm(o) === norm(v))).filter((o): o is string => !!o))];
    }
    if (field.type !== 'checkbox-group') values = values.slice(0, 1);
    if (values.length) fills.push({ id: field.id, type: field.type, values });
    else if (field.required) missing.push({ label: field.label || field.id, note: answer?.note || 'No answer from your profile.' });
  }
  return { fills, missing };
}
