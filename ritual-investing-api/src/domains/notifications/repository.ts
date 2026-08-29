import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";

export function createSupabaseNotificationRepository(
  database: DatabaseTransaction,
) {
  return Object.freeze({
    list: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `select notification.*, null::text as deep_link,
                    notification.created_at as scheduled_at
               from argus_app.notifications notification
              where user_id = (select argus_private.trusted_request_user_id())
              order by created_at desc, id desc
              limit $1`,
          [limit],
        )
      ).rows,
    setRead: async (id: string, read: boolean) => {
      const result = await database.query<JsonObject>(
        `update argus_app.notifications
              set read_at = case when $2 then coalesce(read_at, clock_timestamp()) else null end
            where user_id = argus_private.trusted_request_user_id() and id = $1
          returning *, null::text as deep_link, created_at as scheduled_at`,
        [id, read],
      );
      return first(result.rows);
    },
    readAll: async (before: string) => {
      const result = await database.query<JsonObject>(
        `with updated as (
             update argus_app.notifications
                set read_at=coalesce(read_at,clock_timestamp())
              where user_id=argus_private.trusted_request_user_id()
                and created_at <= $1 and read_at is null
              returning id
           ) select count(*)::int as updated_count from updated`,
        [before],
      );
      return first(result.rows);
    },
    getPreferences: async () => {
      const result = await database.query<JsonObject>(
        `select * from argus_app.notification_preferences
            where user_id = argus_private.trusted_request_user_id()`,
      );
      return first(result.rows);
    },
    updatePreferences: async (patch: JsonObject, expectedVersion: number) => {
      const result = await database.query<JsonObject>(
        `update argus_app.notification_preferences
              set daily_ritual = coalesce(($1::jsonb->>'daily_ritual')::boolean, daily_ritual),
                  weekly_recap = coalesce(($1::jsonb->>'weekly_recap')::boolean, weekly_recap),
                  moon_cycle = coalesce(($1::jsonb->>'moon_cycle')::boolean, moon_cycle),
                  quiet_hours = coalesce($1::jsonb->'quiet_hours', quiet_hours),
                  version = version + 1
            where user_id = argus_private.trusted_request_user_id() and version = $2
          returning *`,
        [patch, expectedVersion],
      );
      if (result.rows.length !== 1) {
        throw new RepositoryRevisionConflictError();
      }
      return result.rows[0]!;
    },
  });
}
