import rawCatalog from './content.json';

export type ChallengeLevel = 'foundation' | 'application' | 'challenge';
export type ChallengeAnswer = {
  display: string;
  choiceId?: string;
  numericValue?: number;
  tolerance?: number;
  unit?: string;
};

export type Challenge = {
  id: string;
  type: 'choice' | 'numeric';
  level: ChallengeLevel;
  section: string;
  concept: string;
  prompt: string;
  choices?: {id: string; label: string}[];
  answer: ChallengeAnswer;
  hints: [string, string];
  explanation: string;
  workedSteps: string[];
  takeaway: string;
};

export type Chapter = {
  id: string;
  number: number;
  title: string;
  description: string;
  focus: string[];
  challenges: Challenge[];
};

export type PracticeCatalog = {
  schemaVersion: 'quant-practice.v1';
  title: string;
  subtitle: string;
  language: 'en';
  createdAt: string;
  provenance: {
    outlineTitle: string;
    outlineUrl: string;
    originalExercises: true;
    calculationEngine: 'offline Python';
    note: string;
  };
  chapters: Chapter[];
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);
const isText = (value: unknown): value is string => typeof value === 'string' && value.trim().length > 0;
const texts = (value: unknown, minimum = 1): value is string[] =>
  Array.isArray(value) && value.length >= minimum && value.every(isText);

/** Fail closed on malformed exported teaching data. No quantitative answers are derived here. */
export function validateCatalog(value: unknown): PracticeCatalog {
  const fail = (): never => {throw new Error('Invalid Quant Quest content artifact');};
  if (!isRecord(value) || value.schemaVersion !== 'quant-practice.v1' || value.language !== 'en'
    || !isText(value.title) || !isText(value.subtitle) || !isText(value.createdAt)
    || !isRecord(value.provenance) || value.provenance.originalExercises !== true
    || value.provenance.calculationEngine !== 'offline Python' || !isText(value.provenance.outlineTitle)
    || !isText(value.provenance.outlineUrl) || !isText(value.provenance.note)
    || !Array.isArray(value.chapters) || value.chapters.length !== 7) return fail();
  const chapterIds = new Set<string>();
  const questionIds = new Set<string>();
  for (const [index, chapter] of value.chapters.entries()) {
    if (!isRecord(chapter) || !isText(chapter.id) || chapterIds.has(chapter.id) || chapter.number !== index + 1
      || !isText(chapter.title) || !isText(chapter.description) || !texts(chapter.focus)
      || !Array.isArray(chapter.challenges) || chapter.challenges.length < 8) return fail();
    chapterIds.add(chapter.id);
    for (const question of chapter.challenges) {
      if (!isRecord(question) || !isText(question.id) || questionIds.has(question.id)
        || !['foundation', 'application', 'challenge'].includes(String(question.level))
        || !isText(question.section) || !isText(question.concept) || !isText(question.prompt)
        || !isText(question.explanation) || !isText(question.takeaway)
        || !texts(question.hints, 2) || question.hints.length !== 2 || !texts(question.workedSteps, 2)
        || !isRecord(question.answer) || !isText(question.answer.display)) return fail();
      questionIds.add(question.id);
      const answer = question.answer;
      if (question.type === 'numeric') {
        if (typeof answer.numericValue !== 'number' || !Number.isFinite(answer.numericValue)
          || typeof answer.tolerance !== 'number' || !Number.isFinite(answer.tolerance) || answer.tolerance <= 0
          || answer.choiceId !== undefined || (answer.unit !== undefined && !isText(answer.unit))) return fail();
        if (answer.unit === 'probability' && (answer.numericValue < 0 || answer.numericValue > 1)) return fail();
      } else if (question.type === 'choice') {
        if (!Array.isArray(question.choices) || question.choices.length < 2 || !isText(answer.choiceId)
          || answer.numericValue !== undefined) return fail();
        const choiceIds = new Set<string>();
        for (const option of question.choices) {
          if (!isRecord(option) || !isText(option.id) || choiceIds.has(option.id) || !isText(option.label)) return fail();
          choiceIds.add(option.id);
        }
        if (!choiceIds.has(answer.choiceId)) return fail();
      } else return fail();
    }
  }
  return value as unknown as PracticeCatalog;
}

export const catalog: PracticeCatalog = validateCatalog(rawCatalog);
