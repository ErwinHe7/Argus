import Anthropic from '@anthropic-ai/sdk';
import { betaZodOutputFormat } from '@anthropic-ai/sdk/helpers/beta/zod';
import type { z } from 'zod';

export interface ClaudeEnv { ANTHROPIC_API_KEY: string; CLAUDE_MODEL: string }

/** One structured-output request; throws instead of returning a partial answer. */
export async function askClaude<Schema extends z.ZodType>(env: ClaudeEnv, request: {
  system: string;
  content: Anthropic.Beta.BetaContentBlockParam[];
  schema: Schema;
  effort: 'low' | 'medium';
}): Promise<z.infer<Schema>> {
  const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
  const response = await client.beta.messages.parse({
    model: env.CLAUDE_MODEL || 'claude-opus-5-5',
    max_tokens: 16000,
    // On a safety decline, rerun on Anthropic's recommended fallback model.
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: request.effort, format: betaZodOutputFormat(request.schema) },
    system: request.system,
    messages: [{ role: 'user', content: request.content }],
  });
  if (response.stop_reason === 'refusal') throw new Error('Claude declined this request.');
  if (response.stop_reason === 'max_tokens') throw new Error('Claude ran out of output space.');
  if (response.parsed_output == null) throw new Error('Claude returned an unreadable answer.');
  return response.parsed_output;
}

export const pdfBlock = (base64: string): Anthropic.Beta.BetaContentBlockParam => ({
  type: 'document',
  source: { type: 'base64', media_type: 'application/pdf', data: base64 },
});
