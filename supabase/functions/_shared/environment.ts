type EnvironmentReader = (name: string) => string | undefined;

const publicBetaConsumerOrigins = Object.freeze([
  "https://just-build-this.app",
  "https://beta.just-build-this.app",
]);

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

export function requiredConsumerOrigins(
  read: EnvironmentReader = (key) => Deno.env.get(key),
): readonly string[] {
  const configured = read("ARGUS_CONSUMER_ORIGINS")?.trim() ?? "";
  const values = configured.split(",").map((value) => value.trim()).filter(
    (value) => value.length > 0,
  );
  if (
    values.length !== publicBetaConsumerOrigins.length ||
    new Set(values).size !== values.length ||
    !publicBetaConsumerOrigins.every((origin) => values.includes(origin))
  ) {
    throw new Error("invalid_argus_consumer_origins");
  }
  return publicBetaConsumerOrigins;
}

export function requiredExactOrigin(
  name: string,
  read: EnvironmentReader = (key) => Deno.env.get(key),
): string {
  const value = requiredEnvironment(name, read);
  try {
    const url = new URL(value);
    if (
      !["http:", "https:"].includes(url.protocol) ||
      url.origin !== value ||
      url.username.length > 0 ||
      url.password.length > 0
    ) {
      throw new Error("not_an_exact_origin");
    }
  } catch {
    throw new Error(`invalid_${name.toLowerCase()}`);
  }
  return value;
}

export function requiredWebAdmission(
  read: EnvironmentReader = (key) => Deno.env.get(key),
): "open" | "contained" {
  const value = read("ARGUS_WEB_ADMISSION")?.trim();
  if (value !== "open" && value !== "contained") {
    throw new Error("invalid_argus_web_admission");
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
