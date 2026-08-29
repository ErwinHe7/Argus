import type { DatabaseTransaction } from "../../db/database-port.ts";
import { first, type JsonObject } from "../../db/repository-support.ts";

export function createSupabaseBriefingRepository(
  database: DatabaseTransaction,
) {
  const selectBriefing =
    `select briefing.*,read_state.read_at
    from argus_app.briefings briefing
    left join argus_app.briefing_read_states read_state
      on read_state.user_id=briefing.user_id
     and read_state.deletion_epoch=briefing.deletion_epoch
     and read_state.briefing_id=briefing.id
   where briefing.user_id=(select argus_private.trusted_request_user_id())`;
  const withSections = async (briefing: JsonObject | null) => {
    if (briefing === null) return null;
    const sections = await database.query<JsonObject>(
      `select ordinal,section_type,source_sequence,schema_version,disclosure
         from argus_private.list_member_briefing_sections($1)`,
      [briefing.id],
    );
    return { ...briefing, sections: sections.rows };
  };
  const listPage = async (input: Readonly<{
    limit: number;
    type: string | undefined;
    periodStart: string | undefined;
    periodEnd: string | undefined;
    after: readonly [periodEnd: string, id: string] | null;
  }>) =>
    (
      await database.query<JsonObject>(
        `select *
           from argus_private.list_member_briefings_page(
             $1,$2,$3,$4,$5,$6
           )`,
        [
          input.limit,
          input.type ?? null,
          input.periodStart ?? null,
          input.periodEnd ?? null,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  return Object.freeze({
    listPage,
    list: async (
      limit: number,
      type?: string,
      periodStart?: string,
      periodEnd?: string,
    ) =>
      listPage({
        limit,
        type,
        periodStart,
        periodEnd,
        after: null,
      }),
    get: async (id: string) => {
      const result = await database.query<JsonObject>(
        `${selectBriefing} and briefing.id = $1
            and briefing.status='ready'`,
        [id],
      );
      return withSections(result.rows[0] ?? null);
    },
    daily: async (localDate: string) => {
      const result = await database.query<JsonObject>(
        `${selectBriefing}
             and briefing.briefing_type='daily'
             and briefing.period_start <= $1 and briefing.period_end >= $1
           order by briefing.generated_at desc nulls last,briefing.id desc
           limit 1`,
        [localDate],
      );
      return withSections(result.rows[0] ?? null);
    },
    setRead: async (id: string, read: boolean) => {
      const result = await database.query<JsonObject>(
        `with target as materialized (
             select briefing.*
               from argus_app.briefings briefing
              where briefing.user_id=(select argus_private.trusted_request_user_id())
                and briefing.id=$1
           ), marked as (
             insert into argus_app.briefing_read_states (
               user_id,deletion_epoch,briefing_id,read_at,updated_at
             )
             select target.user_id,target.deletion_epoch,target.id,
                    clock_timestamp(),clock_timestamp()
               from target
              where $2
             on conflict (user_id,briefing_id) do update
               set deletion_epoch=excluded.deletion_epoch,
                   read_at=excluded.read_at,
                   updated_at=excluded.updated_at
             returning read_at
           ), unmarked as (
             delete from argus_app.briefing_read_states read_state
              using target
              where not $2
                and read_state.user_id=target.user_id
                and read_state.deletion_epoch=target.deletion_epoch
                and read_state.briefing_id=target.id
             returning read_state.briefing_id
           )
           select target.*,
                  case when $2 then (select read_at from marked) else null end as read_at
             from target`,
        [id, read],
      );
      return first(result.rows);
    },
  });
}
