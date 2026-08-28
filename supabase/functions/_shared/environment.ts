type EnvironmentReader = (name: string) => string | undefined;

export function requiredEnvironment(
  name: string,
  read: EnvironmentReader = (key) => Deno.env.get(key),
): string {
  const value = read(name)?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error(`missing_${name.toLowerCase()}`);
  }
  return value;
}

/**
 * Hosted Edge Functions receive the named secret-key dictionary. The singular
 * variable is retained only for the Supabase CLI's local single-key runtime.
 */
export function supabaseSecretKey(
  read: EnvironmentReader = (key) => Deno.env.get(key),
): string {
  const namedKeys = read("SUPABASE_SECRET_KEYS")?.trim();
  if (namedKeys !== undefined && namedKeys.length > 0) {
    try {
      const parsed: unknown = JSON.parse(namedKeys);
      if (
        parsed !== null && typeof parsed === "object" &&
        !Array.isArray(parsed)
      ) {
        const value = (parsed as Record<string, unknown>).default;
        if (typeof value === "string" && value.trim().length > 0) {
          return value.trim();
        }
      }
    } catch {
      // Normalize malformed hosted configuration to the same fail-closed error.
    }
    throw new Error("missing_supabase_secret_keys_default");
  }
  return requiredEnvironment("SUPABASE_SECRET_KEY", read);
}
