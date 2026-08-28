import type { DatabasePool } from "../../../ritual-investing-api/src/db/database-port.ts";
import { withDatabaseTransaction } from "../../../ritual-investing-api/src/db/database-port.ts";
import type { RateLimitPort } from "../../../ritual-investing-api/src/ports/infrastructure.ts";

export function createPostgresRateLimitPort(pool: DatabasePool): RateLimitPort {
  return Object.freeze({
    async allow(
      key: string,
      policy: Readonly<{ limit: number; windowSeconds: number }>,
    ) {
      if (!/^[a-f0-9]{64}$/.test(key)) throw new Error("invalid_rate_scope");
      if (
        !Number.isInteger(policy.limit) ||
        policy.limit < 1 ||
        !Number.isInteger(policy.windowSeconds) ||
        policy.windowSeconds < 1 ||
        policy.windowSeconds > 86_400
      ) {
        throw new Error("invalid_rate_policy");
      }
      return withDatabaseTransaction(pool, "argus_runtime", async (database) => {
        const result = await database.query<{
          allowed: boolean;
          retry_after_seconds: number;
        }>(
          `insert into argus_private.gateway_rate_limits(
             scope_hash, window_started_at, window_seconds, consumed,
             limit_value, updated_at
           ) values ($1, clock_timestamp(), $2, 1, $3, clock_timestamp())
           on conflict (scope_hash) do update set
             window_started_at = case
               when argus_private.gateway_rate_limits.window_started_at
                    + make_interval(secs => argus_private.gateway_rate_limits.window_seconds)
                    <= clock_timestamp()
               then clock_timestamp()
               else argus_private.gateway_rate_limits.window_started_at
             end,
             consumed = case
               when argus_private.gateway_rate_limits.window_started_at
                    + make_interval(secs => argus_private.gateway_rate_limits.window_seconds)
                    <= clock_timestamp()
               then 1
               else argus_private.gateway_rate_limits.consumed + 1
             end,
             window_seconds = excluded.window_seconds,
             limit_value = excluded.limit_value,
             updated_at = clock_timestamp()
           returning consumed <= limit_value as allowed,
             greatest(1, ceil(extract(epoch from (
               window_started_at + make_interval(secs => window_seconds)
               - clock_timestamp()
             )))::integer) as retry_after_seconds`,
          [key, policy.windowSeconds, policy.limit],
        );
        const row = result.rows[0];
        if (row === undefined) throw new Error("rate_limit_result_missing");
        return row.allowed
          ? { allowed: true }
          : {
              allowed: false,
              retryAfterSeconds: row.retry_after_seconds,
            };
      });
    },
  });
}
