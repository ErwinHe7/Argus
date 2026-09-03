const apiKey = process.env.OPENAI_API_KEY;
const baseUrl = process.env.OPENAI_BASE_URL;
const model = process.env.OPENAI_MODEL;

if (!apiKey || !baseUrl || !model) {
  console.log(
    JSON.stringify({
      ok: false,
      error: 'required_environment_missing',
      apiKeyConfigured: Boolean(apiKey),
      baseUrlConfigured: Boolean(baseUrl),
      modelConfigured: Boolean(model),
    })
  );
  process.exitCode = 1;
} else {
  const endpoint = `${baseUrl.replace(/\/$/, '')}/chat/completions`;
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: 'user',
            content: 'Reply with the single word connected.',
          },
        ],
        temperature: 0,
        max_tokens: 20,
      }),
      signal: AbortSignal.timeout(45_000),
    });
    const payload = await response.json().catch(() => ({}));
    console.log(
      JSON.stringify({
        ok: response.ok,
        endpointHost: new URL(endpoint).host,
        status: response.status,
        model,
        content: payload?.choices?.[0]?.message?.content ?? null,
        errorCode: payload?.error?.code ?? null,
        errorMessage: payload?.error?.message ?? null,
      })
    );
    if (!response.ok) process.exitCode = 1;
  } catch (error) {
    console.log(
      JSON.stringify({
        ok: false,
        endpointHost: new URL(endpoint).host,
        model,
        error: error instanceof Error ? error.message : String(error),
      })
    );
    process.exitCode = 1;
  }
}
