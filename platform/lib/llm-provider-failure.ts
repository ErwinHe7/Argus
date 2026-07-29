export type LlmProviderOperation =
  | 'chat_completion'
  | 'model_knowledge'
  | 'quant_research_explanation';

export type LlmProviderFailureCategory =
  | 'authentication'
  | 'rate_limit'
  | 'timeout'
  | 'request_rejected'
  | 'provider_unavailable'
  | 'transport';

export type LlmProviderFailureReceipt = {
  event: 'llm_provider_failure';
  operation: LlmProviderOperation;
  category: LlmProviderFailureCategory;
  http_status: number | null;
  provider_host: string;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null
    ? (value as Record<string, unknown>)
    : null;
}

function httpStatus(error: unknown): number | null {
  const record = asRecord(error);
  const direct = record?.status;
  if (
    typeof direct === 'number' &&
    Number.isInteger(direct) &&
    direct >= 400 &&
    direct <= 599
  ) {
    return direct;
  }

  const cause = asRecord(record?.cause);
  const nested = cause?.status;
  return typeof nested === 'number' &&
    Number.isInteger(nested) &&
    nested >= 400 &&
    nested <= 599
    ? nested
    : null;
}

function isTimeout(error: unknown): boolean {
  const record = asRecord(error);
  return (
    record?.name === 'AbortError' ||
    record?.name === 'TimeoutError' ||
    record?.code === 'ETIMEDOUT' ||
    record?.code === 'UND_ERR_CONNECT_TIMEOUT'
  );
}

function categoryFor(
  error: unknown,
  status: number | null
): LlmProviderFailureCategory {
  if (status === 401 || status === 403) return 'authentication';
  if (status === 408 || isTimeout(error)) return 'timeout';
  if (status === 429) return 'rate_limit';
  if (status !== null && status >= 500) return 'provider_unavailable';
  if (status !== null) return 'request_rejected';
  return 'transport';
}

function providerHost(baseUrl: string | undefined): string {
  if (!baseUrl) return 'api.openai.com';

  try {
    return new URL(baseUrl).host || 'invalid_configuration';
  } catch {
    return 'invalid_configuration';
  }
}

/**
 * Build an allow-listed operational receipt without copying error messages,
 * response bodies, prompts, customer data, credentials, or request headers.
 */
export function buildLlmProviderFailureReceipt(
  error: unknown,
  operation: LlmProviderOperation,
  baseUrl: string | undefined
): LlmProviderFailureReceipt {
  const status = httpStatus(error);
  return {
    event: 'llm_provider_failure',
    operation,
    category: categoryFor(error, status),
    http_status: status,
    provider_host: providerHost(baseUrl),
  };
}
