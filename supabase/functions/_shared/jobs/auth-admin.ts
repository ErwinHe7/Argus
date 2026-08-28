export interface WorkerAuthAdmin {
  deleteUser(userId: string): Promise<void>;
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function createSupabaseAuthAdmin(config: Readonly<{
  supabaseUrl: string;
  secretKey: string;
  fetch?: typeof fetch;
}>): WorkerAuthAdmin {
  const fetcher = config.fetch ?? fetch;
  return Object.freeze({
    async deleteUser(userId: string) {
      if (!uuidPattern.test(userId)) throw new Error("invalid_event_payload");
      const response = await fetcher(
        new URL(`/auth/v1/admin/users/${encodeURIComponent(userId)}`, config.supabaseUrl),
        {
          method: "DELETE",
          headers: {
            apikey: config.secretKey,
          },
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (![200, 204, 404].includes(response.status)) {
        throw new Error("dependency_unavailable");
      }
    },
  });
}
