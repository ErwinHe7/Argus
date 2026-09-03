// Per-token prices in USD. Last updated: 2026-04-25.
// Sources: each provider's pricing page. Update when prices change.
// Prices are per 1 token (not per 1K or 1M).

type ModelPricing = { input: number; output: number };

const PRICING: Record<string, ModelPricing> = {
  // OpenAI — https://openai.com/api/pricing
  'openai/gpt-4o-mini': { input: 0.15e-6, output: 0.6e-6 },
  'openai/gpt-4o': { input: 2.5e-6, output: 10e-6 },

  // Anthropic — https://docs.anthropic.com/en/docs/about-claude/models
  'anthropic/claude-haiku-4.5': { input: 0.8e-6, output: 4e-6 },
  'anthropic/claude-sonnet-4.6': { input: 3e-6, output: 15e-6 },

  // DeepSeek — https://platform.deepseek.com/api-docs/pricing
  'deepseek/deepseek-v3.2': { input: 0.27e-6, output: 1.1e-6 },

  // Nvidia — https://build.nvidia.com pricing page
  'nvidia/nemotron-3-super-120b-a12b': { input: 0.3e-6, output: 0.5e-6 },

  // Qwen — https://help.aliyun.com/zh/model-studio/billing
  'qwen/qwen3.6-plus': { input: 0.5e-6, output: 2e-6 },

  // xAI — https://docs.x.ai/docs/models
  'x-ai/grok-4.1-fast': { input: 5e-6, output: 25e-6 },

  // Google — https://ai.google.dev/pricing
  'google/gemini-3-flash-preview': { input: 0.075e-6, output: 0.3e-6 },
};

export function estimateCost(
  model: string,
  promptTokens: number,
  completionTokens: number
): number {
  const pricing = PRICING[model];
  if (!pricing) return 0;
  return pricing.input * promptTokens + pricing.output * completionTokens;
}
