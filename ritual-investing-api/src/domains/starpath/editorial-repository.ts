import type { DatabaseTransaction } from "../../db/database-port.ts";
import { first, type JsonObject } from "../../db/repository-support.ts";
import type {
  StarpathReviewDecision,
  StarpathReviewDiscipline,
} from "./editorial-schemas.ts";

export interface StarpathEditorialRepository {
  getRevisionAuthority(revisionId: string): Promise<JsonObject>;
  submitRevision(revisionId: string, policyVersion: string): Promise<JsonObject>;
  decideReview(
    revisionId: string,
    discipline: StarpathReviewDiscipline,
    decision: StarpathReviewDecision,
    reason: string,
  ): Promise<JsonObject>;
  publishManifest(manifestId: string, reason: string): Promise<JsonObject>;
}

export function createSupabaseStarpathEditorialRepository(
  database: DatabaseTransaction,
): StarpathEditorialRepository {
  const getRevisionAuthority = async (revisionId: string) =>
    first(
      (
        await database.query<JsonObject>(
          `select revision.id as revision_id,revision.item_id,
                  revision.revision_number,revision.state,
                  revision.payload_canonical_hash as sealed_content_hash,
                  lesson_revision.policy_version,lesson.stable_key,
                  lesson.pathway_ordinal,lesson.pathway_position,
                  coalesce((
                    select jsonb_agg(jsonb_build_object(
                      'request_id',request.id,
                      'discipline',request.discipline,
                      'status',request.status,
                      'sealed_content_hash',request.sealed_content_hash,
                      'policy_version',request.policy_version,
                      'decision',decision.decision,
                      'reviewer_id',decision.reviewer_id,
                      'reason',decision.reason,
                      'decided_at',decision.decided_at
                    ) order by request.discipline)
                    from argus_app.editorial_review_requests request
                    left join argus_app.editorial_review_decisions decision
                      on decision.request_id=request.id
                    where request.revision_id=revision.id
                  ),'[]'::jsonb) as reviews
             from argus_app.editorial_revisions revision
             join argus_app.starpath_lesson_revisions lesson_revision
               on lesson_revision.editorial_item_id=revision.item_id
              and lesson_revision.revision_id=revision.id
             join argus_app.starpath_lessons lesson
               on lesson.id=lesson_revision.lesson_id
            where revision.id=$1`,
          [revisionId],
        )
      ).rows,
    );

  return Object.freeze({
    getRevisionAuthority,
    submitRevision: async (revisionId: string, policyVersion: string) => {
      await database.query(
        `select argus_private.submit_starpath_revision($1,$2)`,
        [revisionId, policyVersion],
      );
      return await getRevisionAuthority(revisionId);
    },
    decideReview: async (
      revisionId: string,
      discipline: StarpathReviewDiscipline,
      decision: StarpathReviewDecision,
      reason: string,
    ) => {
      await database.query(
        `select argus_private.decide_starpath_review($1,$2,$3,$4)`,
        [revisionId, discipline, decision, reason],
      );
      return await getRevisionAuthority(revisionId);
    },
    publishManifest: async (manifestId: string, reason: string) => {
      await database.query(
        `select argus_private.publish_starpath_manifest($1,$2)`,
        [manifestId, reason],
      );
      return first(
        (
          await database.query<JsonObject>(
            `select manifest.id as manifest_id,manifest.manifest_version,
                    manifest.policy_version,manifest.release_environment,
                    manifest.supported_jurisdiction,manifest.state,
                    manifest.published_at,manifest.published_by,
                    manifest.publication_reason,
                    (select count(*)::integer
                       from argus_app.starpath_manifest_nodes node
                      where node.manifest_id=manifest.id) as node_count
               from argus_app.starpath_curriculum_manifests manifest
              where manifest.id=$1`,
            [manifestId],
          )
        ).rows,
      );
    },
  });
}
