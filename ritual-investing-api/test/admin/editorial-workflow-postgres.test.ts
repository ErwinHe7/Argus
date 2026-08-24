import { randomUUID } from "node:crypto";

import pg from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

import type { DatabasePoolFactory } from "../../src/db/client";
import { recordPostgresAdminDenial } from "../../src/domains/admin/access";
import { createPostgresAdminCatalogRepository } from "../../src/domains/admin/catalog/repository";
import { createPostgresAdminEditorialRepository } from "../../src/domains/admin/editorial-workflow/repository";
import { consumeWithReceipt } from "../../src/jobs/consumer-receipts";
import { handlerFor } from "../../src/jobs/handlers";
import { applyReviewedMigrations } from "../../scripts/migrate";

const databaseUrl = process.env.TEST_DATABASE_URL;
const describePostgres = databaseUrl === undefined ? describe.skip : describe;

describePostgres(
  "admin editorial workflow in restricted PostgreSQL roles",
  () => {
    const authorId = randomUUID();
    const reviewerId = randomUUID();
    let owner: pg.Client;
    const poolFactory: DatabasePoolFactory = (url) => {
      const pool = new pg.Pool({ connectionString: url, max: 2 });
      return {
        async connect() {
          return (await pool.connect()) as never;
        },
        async end() {
          await pool.end();
        },
      };
    };

    const payload = {
      scenario_key: `postgres-${randomUUID()}`,
      mode: "tarot",
      cadence: "daily",
      title: "A reviewed PostgreSQL ritual",
      interpretation: "A bounded observation, never a prediction.",
      guidance: "Review your Demo intention and its uncertainty.",
      market_label: "Demo observation",
      observation_at: "2026-08-24T12:00:00.000Z",
      uncertainty: "Demo conditions can change without notice.",
      ideas: [
        {
          asset_id: "20000000-0000-4000-8000-000000000001",
          appearance_reason: "A deterministic fixture.",
          risk_summary: "Market risk remains.",
        },
        {
          asset_id: "20000000-0000-4000-8000-000000000002",
          appearance_reason: "A second deterministic fixture.",
          risk_summary: "Sector concentration remains.",
        },
        {
          asset_id: "20000000-0000-4000-8000-000000000003",
          appearance_reason: "A third deterministic fixture.",
          risk_summary: "Theme exposure remains.",
        },
      ],
      evidence: [
        {
          claim_id: "30000000-0000-4000-8000-000000000001",
          factor_label: "Reviewed fixture evidence",
        },
      ],
    };

    beforeAll(async () => {
      await applyReviewedMigrations(databaseUrl!);
      owner = new pg.Client({ connectionString: databaseUrl! });
      await owner.connect();
      await owner.query(
        `insert into staff_principals(
         id, auth0_subject, access_identity, allowed_client_id, status,
         revocation_epoch, display_label, last_verified_at
       ) values
         ($1, $3, $4, 'ritual-admin-client', 'active', 0, 'Postgres Author', now()),
         ($2, $5, $6, 'ritual-admin-client', 'active', 0, 'Postgres Reviewer', now())`,
        [
          authorId,
          reviewerId,
          `auth0|${authorId}`,
          `${authorId}@ritual.test`,
          `auth0|${reviewerId}`,
          `${reviewerId}@ritual.test`,
        ],
      );
    });

    afterAll(async () => {
      await owner?.end();
    });

    it("atomically drafts, independently reviews, publishes, and audits a Ritual", async () => {
      const repository = createPostgresAdminEditorialRepository(
        databaseUrl!,
        poolFactory,
      );
      const slug = `pg-ritual-${randomUUID()}`;
      const created = await repository.createItem({
        actorStaffId: authorId,
        kind: "ritual_scenario",
        slug,
        payload,
        requestId: randomUUID(),
        idempotencyKey: `create-${randomUUID()}`,
      });
      const revision = created.revision!;

      await repository.requestReview({
        actorStaffId: authorId,
        kind: "ritual_scenario",
        itemId: created.id,
        revisionId: revision.id,
        note: "Evidence and Demo disclosures are ready.",
        highTrust: true,
        requestId: randomUUID(),
        idempotencyKey: `review-${randomUUID()}`,
      });

      await expect(
        repository.decideReview({
          actorStaffId: authorId,
          kind: "ritual_scenario",
          itemId: created.id,
          revisionId: revision.id,
          decision: "approved",
          reason: "Author cannot approve their own high-trust change.",
          requestId: randomUUID(),
          idempotencyKey: `deny-${randomUUID()}`,
        }),
      ).rejects.toThrow("self_approval");

      const denied = await owner.query(
        `select outcome from admin_audit_events
       where actor_staff_id=$1 and target_id=$2 and outcome='denied'`,
        [authorId, revision.id],
      );
      expect(denied.rowCount).toBe(1);

      const approved = await repository.decideReview({
        actorStaffId: reviewerId,
        kind: "ritual_scenario",
        itemId: created.id,
        revisionId: revision.id,
        decision: "approved",
        reason: "Evidence is dated and uncertainty is explicit.",
        requestId: randomUUID(),
        idempotencyKey: `approve-${randomUUID()}`,
      });
      expect(approved.state).toBe("approved");

      const databasePast = await owner.query<{ effective_at: string }>(
        "select (now() - interval '1 minute')::text effective_at",
      );
      const published = await repository.publish({
        actorStaffId: reviewerId,
        kind: "ritual_scenario",
        itemId: created.id,
        revisionId: revision.id,
        effectiveAt: databasePast.rows[0]!.effective_at,
        reason: "Reviewed for immediate publication.",
        requestId: randomUUID(),
        idempotencyKey: `publish-${randomUUID()}`,
      });
      expect(published).toMatchObject({
        status: "published",
        current_published_revision_id: revision.id,
      });

      const persisted = await owner.query(
        `select item.current_published_revision_id, count(audit.id)::integer audit_count
       from editorial_items item
       join admin_audit_events audit on audit.target_id in (item.id, $2)
       where item.id=$1
       group by item.current_published_revision_id`,
        [created.id, revision.id],
      );
      expect(persisted.rows[0]).toMatchObject({
        current_published_revision_id: revision.id,
      });
      expect(persisted.rows[0].audit_count).toBeGreaterThanOrEqual(4);
      const publicationState = await owner.query<{ state: string }>(
        "select state from editorial_revisions where id=$1",
        [revision.id],
      );
      expect(publicationState.rows).toEqual([{ state: "published" }]);

      await expect(
        owner.query("update editorial_revisions set payload='{}' where id=$1", [
          revision.id,
        ]),
      ).rejects.toThrow(/immutable|invalid_transition/i);
    });

    it("keeps direct audit mutation and tenant data outside the staff role", async () => {
      const owners = await owner.query<{ rolname: string }>(
        `select distinct role.rolname
       from pg_proc function
       join pg_namespace namespace on namespace.oid=function.pronamespace
       join pg_roles role on role.oid=function.proowner
       where namespace.nspname='ritual_private'
         and function.proname = any($1::text[])`,
        [
          [
            "record_admin_denial",
            "admin_editorial_publish",
            "admin_catalog_command",
            "admin_moderation_command",
            "apply_scheduled_publication",
          ],
        ],
      );
      expect(owners.rows).toEqual([{ rolname: "ritual_function_owner" }]);

      const client = new pg.Client({ connectionString: databaseUrl! });
      await client.connect();
      try {
        await client.query("begin");
        await client.query("set local role ritual_staff");
        await expect(
          client.query("select id from tenants limit 1"),
        ).rejects.toThrow(/permission denied/i);
        await client.query("rollback");
        await client.query("begin");
        await client.query("set local role ritual_staff");
        await expect(
          client.query(
            `insert into admin_audit_events(
             actor_staff_id,action,target_kind,reason,request_id,outcome
           ) values ($1,'forged','route','forged',$2,'allowed')`,
            [authorId, randomUUID()],
          ),
        ).rejects.toThrow(/permission denied/i);
        await client.query("rollback");
      } finally {
        await client.end();
      }
    });

    it("installs the staff session identity before recording a denied route", async () => {
      const requestId = randomUUID();

      await recordPostgresAdminDenial(
        {
          actorStaffId: authorId,
          permission: "admin:editorial:review",
          method: "POST",
          requestId,
        },
        databaseUrl!,
        poolFactory,
      );

      const audit = await owner.query(
        `select actor_staff_id, action, target_kind, reason, outcome
         from admin_audit_events where request_id=$1`,
        [requestId],
      );
      expect(audit.rows).toEqual([
        {
          actor_staff_id: authorId,
          action: "denied:post:admin:editorial:review",
          target_kind: "route",
          reason: "Missing required permission.",
          outcome: "denied",
        },
      ]);
    });

    it("requires an independent Coven verifier and preserves the denied audit", async () => {
      const repository = createPostgresAdminCatalogRepository(
        databaseUrl!,
        poolFactory,
      );
      const entryId = randomUUID();
      const companyId = randomUUID();
      await owner.query(
        `insert into companies(id,slug,name,is_fictional,status)
       values($1,$2,'Isolated Coven fixture',true,'active')`,
        [companyId, `isolated-coven-${companyId}`],
      );
      const itemId = randomUUID();
      await owner.query(
        `insert into editorial_items(id,kind,slug,status)
       values($1,'coven',$2,'draft')`,
        [itemId, `isolated-coven-${itemId}`],
      );
      await owner.query(
        `insert into coven_entries(id,editorial_item_id,company_id)
       values($1,$2,$3)`,
        [entryId, itemId, companyId],
      );
      const qualification = (await repository.append({
        actorStaffId: authorId,
        action: "coven_qualification",
        parentId: entryId,
        payload: {
          category: "owner",
          person_name: `Independent fixture ${randomUUID()}`,
          valid_from: "2026-08-24",
          valid_to: null,
        },
        requestId: randomUUID(),
        idempotencyKey: `qualification-${randomUUID()}`,
      })) as { id: string };

      await expect(
        repository.append({
          actorStaffId: authorId,
          action: "coven_verification",
          parentId: qualification.id,
          payload: {
            evidence_claim_ids: ["30000000-0000-4000-8000-000000000001"],
            effective_as_of: "2026-08-24",
            decision: "verified",
            reason: "An author cannot verify their own qualification.",
          },
          requestId: randomUUID(),
          idempotencyKey: `self-verification-${randomUUID()}`,
        }),
      ).rejects.toThrow("self_approval");

      const denied = await owner.query(
        `select outcome from admin_audit_events
       where actor_staff_id=$1 and target_id=$2 and outcome='denied'`,
        [authorId, qualification.id],
      );
      expect(denied.rowCount).toBe(1);

      const verification = (await repository.append({
        actorStaffId: reviewerId,
        action: "coven_verification",
        parentId: qualification.id,
        payload: {
          evidence_claim_ids: ["30000000-0000-4000-8000-000000000001"],
          effective_as_of: "2026-08-24",
          decision: "verified",
          reason: "Independently reviewed against dated evidence.",
        },
        requestId: randomUUID(),
        idempotencyKey: `independent-verification-${randomUUID()}`,
      })) as { status: string; verified_by: string };
      expect(verification).toMatchObject({
        status: "verified",
        verified_by: reviewerId,
      });

      const unknownQualificationId = randomUUID();
      await owner.query(
        `insert into coven_qualifications(
           id,entry_id,category,person_name,valid_from,submitted_by
         ) values($1,$2,'owner','Unknown legacy submitter','2026-08-24',null)`,
        [unknownQualificationId, entryId],
      );
      const unknownDenial = await repository.append({
        actorStaffId: reviewerId,
        action: "coven_verification",
        parentId: unknownQualificationId,
        payload: {
          evidence_claim_ids: ["30000000-0000-4000-8000-000000000001"],
          effective_as_of: "2026-08-24",
          decision: "verified",
          reason: "Legacy provenance is not independently verifiable.",
        },
        requestId: randomUUID(),
        idempotencyKey: `unknown-submitter-${randomUUID()}`,
      });
      expect(unknownDenial).toEqual({ _denied: "unknown_submitter" });
      const unknownDenialAudit = await owner.query(
        `select outcome from admin_audit_events
         where actor_staff_id=$1 and target_id=$2 and outcome='denied'`,
        [reviewerId, unknownQualificationId],
      );
      expect(unknownDenialAudit.rowCount).toBe(1);
    });

    it("publishes scheduled revisions monotonically when N+1 arrives before N", async () => {
      const repository = createPostgresAdminEditorialRepository(
        databaseUrl!,
        poolFactory,
      );
      const created = await repository.createItem({
        actorStaffId: authorId,
        kind: "ritual_scenario",
        slug: `pg-schedule-${randomUUID()}`,
        payload: { ...payload, scenario_key: `schedule-${randomUUID()}` },
        requestId: randomUUID(),
        idempotencyKey: `create-${randomUUID()}`,
      });

      const approvedRevisions: string[] = [];
      let sourceRevisionId = created.revision!.id;
      for (const generation of [1, 2]) {
        const draft =
          generation === 1
            ? created
            : await repository.createRevision({
                actorStaffId: authorId,
                kind: "ritual_scenario",
                itemId: created.id,
                sourceRevisionId,
                payload: {
                  ...payload,
                  scenario_key: payload.scenario_key,
                  title: `Scheduled revision ${generation}`,
                },
                requestId: randomUUID(),
                idempotencyKey: `revision-${randomUUID()}`,
              });
        sourceRevisionId = draft.revision!.id;
        await repository.requestReview({
          actorStaffId: authorId,
          kind: "ritual_scenario",
          itemId: created.id,
          revisionId: sourceRevisionId,
          note: `Schedule review ${generation}.`,
          highTrust: true,
          requestId: randomUUID(),
          idempotencyKey: `request-${randomUUID()}`,
        });
        await repository.decideReview({
          actorStaffId: reviewerId,
          kind: "ritual_scenario",
          itemId: created.id,
          revisionId: sourceRevisionId,
          decision: "approved",
          reason: `Independent approval ${generation}.`,
          requestId: randomUUID(),
          idempotencyKey: `decision-${randomUUID()}`,
        });
        const future = await owner.query<{ effective_at: string }>(
          `select (now() + ($1::text || ' hours')::interval)::text effective_at`,
          [generation],
        );
        await repository.publish({
          actorStaffId: reviewerId,
          kind: "ritual_scenario",
          itemId: created.id,
          revisionId: sourceRevisionId,
          effectiveAt: future.rows[0]!.effective_at,
          reason: `Schedule publication ${generation}.`,
          requestId: randomUUID(),
          idempotencyKey: `publish-${randomUUID()}`,
        });
        approvedRevisions.push(sourceRevisionId);
      }

      const events = await owner.query<{ id: string }>(
        `select id from outbox_events
       where topic='editorial.publication.scheduled' and aggregate_id=$1
       order by aggregate_version`,
        [created.id],
      );
      expect(events.rows).toHaveLength(2);
      for (const event of [...events.rows].reverse()) {
        const message = {
          schema_version: 1 as const,
          outbox_id: event.id,
          consumer: "editorial-publisher" as const,
        };
        await expect(
          consumeWithReceipt(
            databaseUrl!,
            message,
            handlerFor(message, {} as never),
            poolFactory,
          ),
        ).resolves.toBe("applied");
      }

      const item = await owner.query<{ current_published_revision_id: string }>(
        "select current_published_revision_id from editorial_items where id=$1",
        [created.id],
      );
      expect(item.rows[0]!.current_published_revision_id).toBe(
        approvedRevisions[1],
      );
      const revision = await owner.query<{ state: string }>(
        "select state from editorial_revisions where id=$1",
        [approvedRevisions[1]],
      );
      expect(revision.rows).toEqual([{ state: "published" }]);
      expect(
        (
          await owner.query(
            `select 1 from consumer_receipts
           where consumer='editorial-publisher' and outbox_id=any($1::uuid[])`,
            [events.rows.map((event) => event.id)],
          )
        ).rowCount,
      ).toBe(2);
    });
  },
);
