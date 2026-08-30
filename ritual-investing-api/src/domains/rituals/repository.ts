import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";
import { ritualAssignmentSchema } from "../engagement/schemas.ts";
import { replaceLegacyDailyTarotProjection } from "./tarot-card-reading.ts";

type RitualProjectionRow = Readonly<{ projection: unknown }>;

function assignmentProjection(row: RitualProjectionRow | undefined) {
  if (row === undefined) return null;
  const assignment = ritualAssignmentSchema.parse(row.projection);
  return ritualAssignmentSchema.parse(
    replaceLegacyDailyTarotProjection(assignment),
  );
}

export function createSupabaseRitualRepository(
  database: DatabaseTransaction,
) {
  const selectAssignment = `select to_jsonb(assignment) || jsonb_build_object(
                    'payload',document.document,
                    'body_template',rowan.body_template,
                    'allowed_tokens',rowan.allowed_tokens,
                    'risk_footer',rowan.risk_footer
                  ) as projection
             from argus_app.daily_ritual_assignments assignment
             join argus_app.editorial_revisions revision
               on revision.id = assignment.revision_id
             join argus_app.editorial_render_documents document
               on document.item_id=revision.item_id and document.revision_id=revision.id
             left join argus_app.rowan_script_revisions rowan
               on rowan.revision_id = assignment.rowan_revision_id
            where assignment.user_id = (select argus_private.trusted_request_user_id())`;
  return Object.freeze({
    getDaily: async (mode?: "tarot" | "astrology") => {
      await database.query(
        `insert into argus_app.daily_ritual_assignments(
           user_id,deletion_epoch,local_date,mode,schedule_id,revision_id,
           rowan_revision_id,state
         )
         select member.user_id,member.deletion_epoch,
                (current_timestamp at time zone preferences.timezone)::date,
                coalesce($1::text,preferences.ritual_mode),
                schedule.id,schedule.revision_id,null::uuid,'assigned'
           from argus_app.members member
           join argus_app.preferences preferences
             on preferences.user_id=member.user_id
           join lateral (
             select candidate.id,candidate.revision_id
               from argus_app.ritual_schedules candidate
              where candidate.mode=coalesce($1::text,preferences.ritual_mode)
                and candidate.audience='member' and candidate.state='active'
                and candidate.local_date <=
                  (current_timestamp at time zone preferences.timezone)::date
                and candidate.effective_at <= current_timestamp
              order by candidate.local_date desc,candidate.effective_at desc,
                       candidate.id desc
              limit 1
           ) schedule on true
          where member.user_id=argus_private.trusted_request_user_id()
            and member.status='active'
         on conflict (user_id,local_date,mode) do nothing`,
        [mode ?? null],
      );
      const result = await database.query<RitualProjectionRow>(
        `${selectAssignment}
             and assignment.local_date=(
               select (current_timestamp at time zone preferences.timezone)::date
                 from argus_app.preferences preferences
                where preferences.user_id=argus_private.trusted_request_user_id()
             )
             and assignment.mode=coalesce($1::text,(
               select preferences.ritual_mode
                 from argus_app.preferences preferences
                where preferences.user_id=argus_private.trusted_request_user_id()
             ))
            limit 1`,
        [mode ?? null],
      );
      return assignmentProjection(result.rows[0]);
    },
    get: async (assignmentId: string) => {
      const result = await database.query<RitualProjectionRow>(
        `${selectAssignment} and assignment.id = $1`,
        [assignmentId],
      );
      return assignmentProjection(result.rows[0]);
    },
    history: async (limit: number) =>
      (
        await database.query<RitualProjectionRow>(
          `${selectAssignment}
              order by assignment.local_date desc, assignment.id desc
              limit $1`,
          [limit],
        )
      ).rows.map((row) => ritualAssignmentSchema.parse(row.projection)),
    evidence: async (assignmentId: string) => {
      const result = await database.query<JsonObject>(
        `select claim.*, to_jsonb(source) as source
             from argus_app.daily_ritual_assignments assignment
             join argus_app.ritual_scenario_revisions scenario
               on scenario.revision_id = assignment.revision_id
             join argus_app.ritual_scenario_revision_evidence evidence
               on evidence.editorial_item_id=scenario.editorial_item_id
              and evidence.revision_id=scenario.revision_id
             join argus_app.evidence_claims claim
               on claim.id=evidence.evidence_claim_id
             join argus_app.evidence_sources source on source.id = claim.source_id
            where assignment.user_id = (select argus_private.trusted_request_user_id())
              and assignment.id = $1
              and claim.status = 'active' and source.status = 'active'
            order by evidence.ordinal`,
        [assignmentId],
      );
      return result.rows;
    },
    transition: async (
      assignmentId: string,
      from: "assigned" | "revealed",
      to: "revealed" | "completed",
      expectedVersion: number,
    ) => {
      const result = await database.query<{ id: string }>(
        `update argus_app.daily_ritual_assignments
              set state = $3,
                  revealed_at = case when $3 = 'revealed'
                    then coalesce(revealed_at, clock_timestamp()) else revealed_at end,
                  completed_at = case when $3 = 'completed'
                    then coalesce(completed_at, clock_timestamp()) else completed_at end,
                  version = version + 1
            where user_id = argus_private.trusted_request_user_id() and id = $1 and state = $2
              and version = $4
          returning id`,
        [assignmentId, from, to, expectedVersion],
      );
      if (result.rows.length !== 1) {
        throw new RepositoryRevisionConflictError();
      }
      const projectionResult = await database.query<RitualProjectionRow>(
        `${selectAssignment} and assignment.id = $1 limit 1`,
        [assignmentId],
      );
      const projection = assignmentProjection(projectionResult.rows[0]);
      if (projection === null) {
        throw new Error("ritual_transition_projection_missing");
      }
      return projection;
    },
    getSchedule: async (localDate: string, mode: "tarot" | "astrology") => {
      const result = await database.query<JsonObject>(
        `select schedule.*, document.document as payload
             from argus_app.ritual_schedules schedule
             join argus_app.editorial_revisions revision
               on revision.id = schedule.revision_id
             join argus_app.editorial_render_documents document
               on document.item_id=revision.item_id and document.revision_id=revision.id
            where schedule.local_date = $1 and schedule.mode = $2
              and schedule.audience = 'member' and schedule.state = 'active'`,
        [localDate, mode],
      );
      return result.rows[0] ?? null;
    },
    getScenario: async (revisionId: string) => {
      const result = await database.query<JsonObject>(
        `select * from argus_app.ritual_scenario_revisions
            where revision_id = $1`,
        [revisionId],
      );
      return result.rows[0] ?? null;
    },
  });
}
