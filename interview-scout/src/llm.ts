import type { z } from 'zod';

// The resume reader and form answerer run on Google's Gemini API (free tier at
// https://aistudio.google.com/apikey). We call the REST endpoint directly so
// the Worker bundle carries no SDK, and validate every reply against a Zod
// schema so a malformed or declined answer fails closed instead of guessing.

export interface LlmEnv { GEMINI_API_KEY: string; GEMINI_MODEL: string }

export type Part = { text: string } | { inlineData: { mimeType: string; data: string } };

/** A Gemini `responseSchema`: an OpenAPI subset with uppercase type names. */
export type ResponseSchema = {
  type: 'OBJECT' | 'ARRAY' | 'STRING' | 'BOOLEAN' | 'NUMBER' | 'INTEGER';
  properties?: Record<string, ResponseSchema>;
  items?: ResponseSchema;
  required?: string[];
  propertyOrdering?: string[];
};

export const STRING: ResponseSchema = { type: 'STRING' };
export const STRING_ARRAY: ResponseSchema = { type: 'ARRAY', items: { type: 'STRING' } };

/** One structured-output request; throws instead of returning a partial answer. */
export async function ask<Schema extends z.ZodType>(env: LlmEnv, request: {
  system: string;
  parts: Part[];
  schema: Schema;
  responseSchema: ResponseSchema;
}): Promise<z.infer<Schema>> {
  const model = env.GEMINI_MODEL || 'gemini-2.5-flash';
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: request.system }] },
      contents: [{ role: 'user', parts: request.parts }],
      generationConfig: { temperature: 0, responseMimeType: 'application/json', responseSchema: request.responseSchema },
    }),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`Gemini request failed (${response.status}). ${detail.slice(0, 200)}`);
  }
  const data = await response.json() as GeminiResponse;
  const blocked = data.promptFeedback?.blockReason;
  if (blocked) throw new Error(`Gemini declined this request (${blocked}).`);
  const candidate = data.candidates?.[0];
  if (candidate?.finishReason && candidate.finishReason !== 'STOP') {
    throw new Error(`Gemini stopped early (${candidate.finishReason}).`);
  }
  const text = (candidate?.content?.parts ?? []).map(p => p.text ?? '').join('');
  if (!text) throw new Error('Gemini returned an empty answer.');
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error('Gemini returned unreadable JSON.');
  }
  const result = request.schema.safeParse(parsed);
  if (!result.success) throw new Error('Gemini returned data that did not match the expected shape.');
  return result.data;
}

export const pdfPart = (base64: string): Part => ({ inlineData: { mimeType: 'application/pdf', data: base64 } });

interface GeminiResponse {
  promptFeedback?: { blockReason?: string };
  candidates?: { finishReason?: string; content?: { parts?: { text?: string }[] } }[];
}
