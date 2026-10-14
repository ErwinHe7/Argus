// Secrets are not declared in wrangler.jsonc (so the site can deploy before
// they exist), so `wrangler types` does not generate them.
interface Env {
  GEMINI_API_KEY: string;
  ACCESS_CODE: string;
}
