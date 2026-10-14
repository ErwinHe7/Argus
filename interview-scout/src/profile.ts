import { z } from 'zod';
import { askClaude, pdfBlock, type ClaudeEnv } from './claude.ts';

export const ProfileSchema = z.object({
  fullName: z.string(),
  firstName: z.string(),
  lastName: z.string(),
  email: z.string(),
  phone: z.string(),
  location: z.string(),
  linkedin: z.string(),
  website: z.string(),
  github: z.string(),
  currentTitle: z.string(),
  currentCompany: z.string(),
  education: z.string(),
  skills: z.array(z.string()),
  summary: z.string(),
  targetTitles: z.array(z.string()),
});
export type Profile = z.infer<typeof ProfileSchema>;

const SYSTEM = `You read resumes and extract a candidate profile for job applications.
Copy contact details exactly as written. Leave any field the resume does not state as an empty string; never guess.
education: highest degree, school and graduation year on one line.
summary: two factual sentences about the candidate's experience, using only what the resume says.
targetTitles: 3 to 5 short job titles (2-3 words each, no seniority words) that fit this resume, for searching job boards.`;

export function extractProfile(env: ClaudeEnv, resumeBase64: string): Promise<Profile> {
  return askClaude(env, {
    system: SYSTEM,
    content: [pdfBlock(resumeBase64), { type: 'text', text: 'Extract the profile from this resume.' }],
    schema: ProfileSchema,
    effort: 'low',
  });
}
