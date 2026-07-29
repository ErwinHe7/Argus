import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { buildLlmProviderFailureReceipt } from '../lib/llm-provider-failure.ts';

const read = (path) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('a provider 401 produces a useful receipt without copying secrets or content', () => {
  const error = {
    status: 401,
    message:
      'Bearer sk-live-secret failed for customer@example.com; prompt: private',
    response: {
      body: 'provider response body with private content',
    },
  };
  const receipt = buildLlmProviderFailureReceipt(
    error,
    'model_knowledge',
    'https://user:password@router.example.test:8443/v1'
  );

  assert.deepEqual(receipt, {
    event: 'llm_provider_failure',
    operation: 'model_knowledge',
    category: 'authentication',
    http_status: 401,
    provider_host: 'router.example.test:8443',
  });

  const serialized = JSON.stringify(receipt);
  for (const privateValue of [
    'sk-live-secret',
    'customer@example.com',
    'private content',
    'password',
  ]) {
    assert.ok(!serialized.includes(privateValue));
  }
});

test('provider failures are classified from allow-listed metadata only', () => {
  assert.equal(
    buildLlmProviderFailureReceipt(
      { status: 429 },
      'chat_completion',
      undefined
    ).category,
    'rate_limit'
  );
  assert.equal(
    buildLlmProviderFailureReceipt(
      { status: 503 },
      'quant_research_explanation',
      'not a URL'
    ).category,
    'provider_unavailable'
  );
  assert.equal(
    buildLlmProviderFailureReceipt(
      { code: 'ETIMEDOUT' },
      'chat_completion',
      undefined
    ).category,
    'timeout'
  );
});

test('chat telemetry never captures the raw provider exception', () => {
  const llm = read('lib/llm.ts');
  const conversation = read('lib/quant/conversation.ts');

  assert.match(llm, /buildLlmProviderFailureReceipt/);
  assert.match(llm, /captureMessage\(['"]LLM provider request failed['"]/);
  assert.doesNotMatch(llm, /captureException/);
  assert.match(conversation, /operation:\s*['"]model_knowledge['"]/);
  assert.match(
    conversation,
    /operation:\s*['"]quant_research_explanation['"]/
  );
});
