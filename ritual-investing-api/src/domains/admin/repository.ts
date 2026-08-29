import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";
import { sha256TextHex } from "../../security/sha256.ts";

export function createSupabaseAdminRepository(
  database: DatabaseTransaction,
  actor: Readonly<{ userId: string; sessionId: string }>,
) {
  type EditorialKind =
    | "ritual"
    | "asset_codex"
    | "coven"
    | "grimoire"
    | "circle_template"
    | "rowan"
    | "briefing_template";

  const createEditorialKindRecord = async (
    database: DatabaseTransaction,
    kind: EditorialKind,
    itemId: string,
    payload: JsonObject,
  ): Promise<void> => {
    const functions: Partial<Record<EditorialKind, string>> = {
      ritual: "argus_private.create_ritual_editorial_item",
      coven: "argus_private.create_coven_editorial_item",
      grimoire: "argus_private.create_grimoire_editorial_item",
      circle_template: "argus_private.create_circle_template_editorial_item",
      rowan: "argus_private.create_rowan_editorial_item",
    };
    const functionName = functions[kind];
    if (functionName !== undefined) {
      await database.query(
        `select ${functionName}($1,$2::jsonb)`,
        [itemId, JSON.stringify(payload)],
      );
    }
  };

  const syncEditorialRevision = async (
    database: DatabaseTransaction,
    kind: EditorialKind,
    revisionId: string,
    payload: JsonObject,
  ): Promise<void> => {
    const functions: Partial<Record<EditorialKind, string>> = {
      ritual: "argus_private.sync_ritual_revision",
      asset_codex: "argus_private.sync_asset_codex_revision",
      coven: "argus_private.sync_coven_revision",
      grimoire: "argus_private.sync_grimoire_revision",
      circle_template: "argus_private.sync_circle_template_revision",
      rowan: "argus_private.sync_rowan_revision",
    };
    const functionName = functions[kind];
    if (functionName !== undefined) {
      await database.query(
        `select ${functionName}($1,$2::jsonb)`,
        [revisionId, JSON.stringify(payload)],
      );
    }
  };

  const viewEditorialItem = async (
    database: DatabaseTransaction,
    itemId: string,
  ): Promise<JsonObject> =>
    first(
      (
        await database.query<JsonObject>(
          `select item.id,item.kind,item.slug,item.status,
                  revision.id as revision_id,revision.revision_number,
                  revision.edit_version as version,revision.state as revision_state,
                  '"v' || revision.edit_version || '"' as etag
             from argus_app.editorial_items item
             join lateral (
               select * from argus_app.editorial_revisions candidate
                where candidate.item_id=item.id
                order by candidate.revision_number desc,candidate.id desc
                limit 1
             ) revision on true
            where item.id=$1`,
          [itemId],
        )
      ).rows,
    );
  const auditEditorial = (
    database: DatabaseTransaction,
    action: string,
    itemId: string,
    outcome: "allowed" | "denied" | "failed",
    requestId: string,
    reasonCode: string | null = null,
  ) =>
    database.query(
      `insert into argus_private.admin_audit_events(
         actor_user_id,action,target_kind,target_id,outcome,reason_code,
         correlation_id,details
       ) values (
         argus_private.trusted_request_user_id(),$1,'editorial_item',$2,$3,$4,$5,'{}'::jsonb
       )`,
      [action, itemId, outcome, reasonCode, requestId],
    );

  return Object.freeze({
    getStaffPrincipal: async () => {
      const result = await database.query<JsonObject>(
        `select user_id,display_label,permissions,revocation_epoch
             from argus_private.staff_principals
            where user_id = argus_private.request_user_id() and status = 'active'`,
      );
      return result.rows[0] ?? null;
    },
    issueStepUp: async (
      action: "admin_job_retry" | "admin_privacy_retry",
      targetId: string,
    ) => {
      const receipt = `${crypto.randomUUID().replaceAll("-", "")}${
        crypto.randomUUID().replaceAll("-", "")
      }`;
      await database.query(
        `insert into argus_private.staff_step_up_receipts(
             user_id,session_id,action,target_id,receipt_hash,expires_at
           ) values (argus_private.request_user_id(),$1,$2,$3,$4,
                     clock_timestamp()+interval '5 minutes')`,
        [
          actor.sessionId,
          action,
          targetId,
          await sha256TextHex(receipt),
        ],
      );
      return receipt;
    },
    listAudit: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `select id,actor_user_id,action,target_kind,target_id,outcome,
                    reason_code,correlation_id,occurred_at
               from argus_private.admin_audit_events
              order by occurred_at desc, id desc
              limit $1`,
          [limit],
        )
      ).rows,
    listEditorial: async (limit: number, kind?: string) =>
      (
        await database.query<JsonObject>(
          `select item.id,item.kind,item.slug,item.status,
                    revision.id as revision_id,revision.revision_number,
                    revision.edit_version as version,
                    revision.state as revision_state,
                    '"v' || revision.edit_version || '"' as etag
               from argus_app.editorial_items item
               join lateral (
                 select * from argus_app.editorial_revisions candidate
                  where candidate.item_id=item.id
                  order by candidate.revision_number desc,candidate.id desc
                  limit 1
               ) revision on true
              where ($2::text is null or item.kind=$2)
              order by item.created_at desc, item.id desc
              limit $1`,
          [limit, kind ?? null],
        )
      ).rows,
    getEditorial: async (itemId: string) => {
      const item = await viewEditorialItem(database, itemId);
      const revision = first(
        (
          await database.query<JsonObject>(
            `select id,revision_number,edit_version as version,state,
                      author_staff_id,content_hash,payload,created_at,
                      '"v' || edit_version || '"' as etag
                 from argus_app.editorial_revisions
                where item_id=$1
                order by revision_number desc,id desc limit 1`,
            [itemId],
          )
        ).rows,
      );
      return { ...item, revision };
    },
    createEditorial: async (
      kind:
        | "ritual"
        | "asset_codex"
        | "coven"
        | "grimoire"
        | "circle_template"
        | "rowan"
        | "briefing_template",
      slug: string,
      payload: JsonObject,
      requestId: string,
    ) => {
      const item = first(
        (
          await database.query<{ id: string }>(
            `insert into argus_app.editorial_items(kind,slug,status)
               values ($1,$2,'draft') returning id`,
            [kind, slug],
          )
        ).rows,
      );
      const revision = first(
        (await database.query<{ id: string }>(
          `insert into argus_app.editorial_revisions(
             item_id,revision_number,state,author_staff_id,content_hash,payload
           ) values ($1,1,'draft',argus_private.trusted_request_user_id(),$2,$3::jsonb)
           returning id`,
          [
            item.id,
            await sha256TextHex(JSON.stringify(payload)),
            JSON.stringify(payload),
          ],
        )).rows,
      );
      await createEditorialKindRecord(database, kind, item.id, payload);
      await syncEditorialRevision(database, kind, revision.id, payload);
      await auditEditorial(
        database,
        "editorial.create",
        item.id,
        "allowed",
        requestId,
      );
      return viewEditorialItem(database, item.id);
    },
    createEditorialRevision: async (
      itemId: string,
      payload: JsonObject,
      requestId: string,
    ) => {
      const item = first(
        (
          await database.query<{ id: string; kind: EditorialKind }>(
            `select id,kind from argus_app.editorial_items where id=$1 for update`,
            [itemId],
          )
        ).rows,
      );
      const revision = first(
        (await database.query<{ id: string }>(
          `insert into argus_app.editorial_revisions(
             item_id,revision_number,state,author_staff_id,content_hash,payload
           ) select $1,coalesce(max(revision_number),0)+1,'draft',
                    argus_private.trusted_request_user_id(),$2,$3::jsonb
               from argus_app.editorial_revisions where item_id=$1
           returning id`,
          [
            item.id,
            await sha256TextHex(JSON.stringify(payload)),
            JSON.stringify(payload),
          ],
        )).rows,
      );
      await syncEditorialRevision(database, item.kind, revision.id, payload);
      await auditEditorial(
        database,
        "editorial.revision.create",
        item.id,
        "allowed",
        requestId,
      );
      return viewEditorialItem(database, item.id);
    },
    patchEditorialRevision: async (
      itemId: string,
      revisionId: string,
      expectedVersion: number,
      payload: JsonObject,
      requestId: string,
    ) => {
      const item = first(
        (await database.query<{ kind: EditorialKind }>(
          `select kind from argus_app.editorial_items where id=$1 for update`,
          [itemId],
        )).rows,
      );
      const result = await database.query<{ id: string }>(
        `update argus_app.editorial_revisions
              set payload=$1::jsonb,content_hash=$2,edit_version=edit_version+1
            where id=$3 and item_id=$4 and state='draft' and edit_version=$5
          returning id`,
        [
          JSON.stringify(payload),
          await sha256TextHex(JSON.stringify(payload)),
          revisionId,
          itemId,
          expectedVersion,
        ],
      );
      if (result.rows.length === 0) throw new RepositoryRevisionConflictError();
      await syncEditorialRevision(database, item.kind, revisionId, payload);
      await auditEditorial(
        database,
        "editorial.revision.patch",
        itemId,
        "allowed",
        requestId,
      );
      return viewEditorialItem(database, itemId);
    },
    commandEditorial: async (
      action:
        | "request_review"
        | "approve"
        | "changes_requested"
        | "publish"
        | "withdraw",
      itemId: string,
      revisionId: string | null,
      reason: string,
      highTrust: boolean,
      requestId: string,
    ) => {
      return (async () => {
        if (action === "request_review") {
          const revision = first(
            (
              await database.query<
                { id: string; kind: string; payload: JsonObject }
              >(
                `select revision.id,item.kind,revision.payload
                   from argus_app.editorial_revisions revision
                   join argus_app.editorial_items item on item.id=revision.item_id
                  where revision.id=$1 and revision.item_id=$2
                    and revision.state='draft'
                  for update of revision`,
                [revisionId, itemId],
              )
            ).rows,
          );
          await syncEditorialRevision(
            database,
            revision.kind as EditorialKind,
            revision.id,
            revision.payload,
          );
          await database.query(
            `update argus_app.editorial_revisions set state='submitted'
              where id=$1`,
            [revision.id],
          );
          await database.query(
            `insert into argus_app.editorial_review_requests(
               revision_id,requested_by,high_trust,status
             ) values (
               $1,argus_private.trusted_request_user_id(),
               ($2 or $3 in ('ritual','rowan')),'open'
             )`,
            [revision.id, highTrust, revision.kind],
          );
        } else if (action === "approve" || action === "changes_requested") {
          const request = first(
            (
              await database.query<{
                id: string;
                author_staff_id: string;
                high_trust: boolean;
              }>(
                `select review.id,revision.author_staff_id,review.high_trust
                   from argus_app.editorial_review_requests review
                   join argus_app.editorial_revisions revision on revision.id=review.revision_id
                  where review.revision_id=$1 and revision.item_id=$2
                    and review.status='open' and revision.state='submitted'
                  for update`,
                [revisionId, itemId],
              )
            ).rows,
          );
          if (
            request.high_trust === true &&
            request.author_staff_id === actor.userId
          ) {
            await auditEditorial(
              database,
              "editorial.review.decision",
              itemId,
              "denied",
              requestId,
              "self_approval",
            );
            return { _denied: "self_approval" };
          }
          const decision = action === "approve"
            ? "approved"
            : "changes_requested";
          await database.query(
            `insert into argus_app.editorial_review_decisions(
               request_id,reviewer_id,decision,reason
             ) values ($1,argus_private.trusted_request_user_id(),$2,$3)`,
            [request.id, decision, reason],
          );
          await database.query(
            `update argus_app.editorial_review_requests set status='closed' where id=$1`,
            [request.id],
          );
          await database.query(
            `update argus_app.editorial_revisions set state=$1 where id=$2`,
            [action === "approve" ? "approved" : "rejected", revisionId],
          );
        } else if (action === "publish") {
          await database.query(
            `select argus_private.publish_editorial_revision($1,$2,$3)`,
            [itemId, revisionId, reason],
          );
        } else {
          const item = first(
            (
              await database.query<{ current_published_revision_id: string }>(
                `update argus_app.editorial_items set status='withdrawn'
                  where id=$1 and status='published'
                  returning current_published_revision_id`,
                [itemId],
              )
            ).rows,
          );
          await database.query(
            `update argus_app.editorial_revisions set state='withdrawn'
              where id=$1 and state='published'`,
            [item.current_published_revision_id],
          );
          await database.query(
            `insert into argus_app.publication_events(
               item_id,revision_id,action,effective_at,actor_id,reason
             ) values ($1,$2,'withdraw',clock_timestamp(),argus_private.trusted_request_user_id(),$3)`,
            [itemId, item.current_published_revision_id, reason],
          );
        }
        await auditEditorial(
          database,
          `editorial.${action}`,
          itemId,
          "allowed",
          requestId,
        );
        return viewEditorialItem(database, itemId);
      })();
    },
  });
}
