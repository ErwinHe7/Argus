import { z } from 'zod';
import { ask, pdfPart, STRING, STRING_ARRAY, type LlmEnv, type ResponseSchema } from './llm.ts';

export const ProfileSchema = z.object({
  fullName: z.string().max(200),
  firstName: z.string().max(100),
  lastName: z.string().max(100),
  email: z.string().max(254).refine(value => !value || z.email().safeParse(value).success, 'Enter a valid email address.'),
  phone: z.string().max(100),
  location: z.string().max(300),
  linkedin: z.string().max(1000),
  website: z.string().max(1000),
  github: z.string().max(1000),
  currentTitle: z.string().max(300),
  currentCompany: z.string().max(300),
  education: z.string().max(2000),
  skills: z.array(z.string().max(200)).max(100),
  summary: z.string().max(5000),
  targetTitles: z.array(z.string().max(200)).max(20),
});
export type Profile = z.infer<typeof ProfileSchema>;

const SYSTEM = `You read resumes and extract a candidate profile for job applications.
Copy contact details exactly as written. Leave any field the resume does not state as an empty string; never guess.
education: highest degree, school and graduation year on one line.
summary: two factual sentences about the candidate's experience, using only what the resume says.
targetTitles: 3 to 5 short job titles (2-3 words each, no seniority words) that fit this resume, for searching job boards.`;

const RESPONSE_SCHEMA: ResponseSchema = {
  type: 'OBJECT',
  properties: {
    fullName: STRING, firstName: STRING, lastName: STRING, email: STRING, phone: STRING, location: STRING,
    linkedin: STRING, website: STRING, github: STRING, currentTitle: STRING, currentCompany: STRING, education: STRING,
    skills: STRING_ARRAY, summary: STRING, targetTitles: STRING_ARRAY,
  },
  required: ['fullName', 'firstName', 'lastName', 'email', 'phone', 'location', 'linkedin', 'website',
    'github', 'currentTitle', 'currentCompany', 'education', 'skills', 'summary', 'targetTitles'],
};

export function extractProfile(env: LlmEnv, resumeBase64: string): Promise<Profile> {
  return ask(env, {
    system: SYSTEM,
    parts: [pdfPart(resumeBase64), { text: 'Extract the profile from this resume.' }],
    schema: ProfileSchema,
    responseSchema: RESPONSE_SCHEMA,
  });
}
