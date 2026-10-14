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
  const model = env.GEMINI_MODEL || 'gemini-3.5-flash-lite';
  const controller = new AbortController();
  // Covers response-body reads as well as the initial request.
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    let response: Response;
    try {
      response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: 'POST',
        redirect: 'manual',
        signal: controller.signal,
        headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: request.system }] },
          contents: [{ role: 'user', parts: request.parts }],
          generationConfig: { responseMimeType: 'application/json', responseSchema: request.responseSchema },
        }),
      });
    } catch {
      throw new Error(controller.signal.aborted ? 'Gemini request timed out. Try again.' : 'Gemini request could not be completed. Try again.');
    }
    // Provider bodies can include applicant data. Expose only the numeric status.
    if (!response.ok) throw new Error(`Gemini request failed (${response.status}).`);
    let data: GeminiResponse;
    try {
      const value: unknown = await response.json();
      if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
      data = value as GeminiResponse;
    } catch {
      throw new Error(controller.signal.aborted ? 'Gemini request timed out. Try again.' : 'Gemini returned an unreadable response.');
    }
    if (data.promptFeedback?.blockReason) throw new Error('Gemini declined this request.');
    const candidate = Array.isArray(data.candidates) ? data.candidates[0] : undefined;
    if (!candidate || candidate.finishReason !== 'STOP') throw new Error('Gemini stopped before returning a complete answer.');
    const parts = candidate.content?.parts;
    if (!Array.isArray(parts) || parts.some(part => !part || typeof part.text !== 'string')) throw new Error('Gemini returned an empty or invalid answer.');
    const text = parts.map(part => part.text).join('');
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
  } finally {
    clearTimeout(timeout);
  }
}

export const pdfPart = (base64: string): Part => ({ inlineData: { mimeType: 'application/pdf', data: base64 } });

interface GeminiResponse {
  promptFeedback?: { blockReason?: string };
  candidates?: { finishReason?: string; content?: { parts?: { text?: string }[] } }[];
}
