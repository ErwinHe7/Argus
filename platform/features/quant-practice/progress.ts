export const PROGRESS_KEY = 'leo.quant-practice.v1';
export type AnswerRecord = { attempts: number; completed: boolean; independentCorrect: number; needsReview: boolean; lastAt: string };
export type PracticeProgress = { schemaVersion: 'leo-learning-progress.v1'; updatedAt: string; answers: Record<string, AnswerRecord>; labs: string[] };
const iso = (value: unknown): value is string => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value) && Number.isFinite(Date.parse(value));
const object = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === 'object' && !Array.isArray(value);
const count = (value: unknown): value is number => Number.isSafeInteger(value) && Number(value) >= 0 && Number(value) <= 100000;
export function emptyProgress(now = new Date().toISOString()): PracticeProgress {
  return { schemaVersion: 'leo-learning-progress.v1', updatedAt: now, answers: {}, labs: [] };
}
export function parseProgress(raw: string, questionIds: ReadonlySet<string>): PracticeProgress {
  if (raw.length > 200000) throw new Error('This file is too large to be a practice-progress export.');
  const value: unknown = JSON.parse(raw);
  if (!object(value) || value.schemaVersion !== 'leo-learning-progress.v1' || !iso(value.updatedAt) || !object(value.answers) || !Array.isArray(value.labs) || value.labs.length > 256) throw new Error('This is not a supported practice-progress export.');
  if (Object.keys(value.answers).length > questionIds.size) throw new Error('Progress contains unknown exercises.');
  const answers: Record<string, AnswerRecord> = {};
  for (const [id, row] of Object.entries(value.answers)) {
    if (!questionIds.has(id) || !object(row) || !count(row.attempts) || !count(row.independentCorrect) || row.independentCorrect > row.attempts || typeof row.completed !== 'boolean' || typeof row.needsReview !== 'boolean' || !iso(row.lastAt) || (row.completed && row.attempts < 1) || (row.independentCorrect > 0 && !row.completed)) throw new Error('Progress contains an invalid exercise record.');
    answers[id] = { attempts: row.attempts, completed: row.completed, independentCorrect: row.independentCorrect, needsReview: row.needsReview, lastAt: row.lastAt };
  }
  if (value.labs.some(id => typeof id !== 'string' || !/^[a-z0-9:_-]{1,100}$/.test(id))) throw new Error('Progress contains an invalid lab record.');
  return { schemaVersion: 'leo-learning-progress.v1', updatedAt: value.updatedAt, answers, labs: [...new Set(value.labs as string[])] };
}
export function recordAnswer(progress: PracticeProgress, id: string, correct: boolean, assisted: boolean, now = new Date().toISOString()): PracticeProgress {
  const previous = progress.answers[id];
  return { ...progress, updatedAt: now, answers: { ...progress.answers, [id]: {
    attempts: Math.min(100000, (previous?.attempts ?? 0) + 1),
    completed: Boolean(previous?.completed || correct),
    independentCorrect: Math.min(100000, (previous?.independentCorrect ?? 0) + (correct && !assisted ? 1 : 0)),
    needsReview: !correct || assisted, lastAt: now,
  } } };
}
export function recordExposure(progress: PracticeProgress, id: string, now = new Date().toISOString()): PracticeProgress {
  const previous = progress.answers[id] ?? { attempts: 0, completed: false, independentCorrect: 0, needsReview: true, lastAt: now };
  return { ...progress, updatedAt: now, answers: { ...progress.answers, [id]: { ...previous, needsReview: true, lastAt: now } } };
}
export function recordLab(progress: PracticeProgress, id: string, now = new Date().toISOString()): PracticeProgress {
  return { ...progress, updatedAt: now, labs: [...new Set([...progress.labs, id])].slice(-256) };
}
export function mergeProgress(current: PracticeProgress, incoming: PracticeProgress): PracticeProgress {
  const answers = { ...current.answers };
  for (const [id, row] of Object.entries(incoming.answers)) if (!answers[id] || Date.parse(row.lastAt) > Date.parse(answers[id]!.lastAt)) answers[id] = row;
  return { schemaVersion: 'leo-learning-progress.v1', updatedAt: new Date().toISOString(), answers, labs: [...new Set([...current.labs, ...incoming.labs])].slice(-256) };
}
export function parseNumericAnswer(raw: string, unit?: string): number | undefined {
  let clean = raw.trim().replace(/−/g, '-');
  const percent = clean.endsWith('%');
  if (percent) clean = clean.slice(0, -1).trim();
  if (unit === '$' || unit === 'USD') clean = clean.replace(/^\$/, '');
  const parts = clean.split('/').map(value => value.trim());
  const numberPattern = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i;
  if (parts.length < 1 || parts.length > 2 || parts.some(value => !numberPattern.test(value))) return undefined;
  const denominator = parts.length === 2 ? Number(parts[1]) : 1;
  if (denominator === 0) return undefined;
  const value = Number(parts[0]) / denominator / (percent && unit !== '%' ? 100 : 1);
  return Number.isFinite(value) ? value : undefined;
}
