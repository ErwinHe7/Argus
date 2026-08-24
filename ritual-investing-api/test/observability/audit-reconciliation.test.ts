import { randomUUID } from "node:crypto";

import pg from "pg";
import { describe, expect, it } from "vitest";

import { reconcileAdminAudit } from "../../src/jobs/scheduled.ts";
import { pgPoolFactory } from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

async function ownerClient() {
  const client = new pg.Client({ connectionString: databaseUrl! });
  await client.connect();
  return client;
}

describe.skipIf(databaseUrl === undefined)(
  "restricted immutable admin audit reconciliation",
  () => {
    it("records a stable digest while denying runtime, raw audit access, and mutation", async () => {
      const staffId = randomUUID();
      const cutoff = new Date(Date.now() - 1_000);
      const beforeCutoff = new Date(cutoff.getTime() - 1_000);
      const owner = await ownerClient();
      try {
        await owner.query(
          `insert into staff_principals(id,auth0_subject,access_identity,allowed_client_id,status,display_label)
           values ($1,$2,$3,'ritual-admin-client','active','Audit Reconciler Fixture')`,
          [staffId, `auth0|audit-${staffId}`, `audit-${staffId}@example.test`],
        );
        await owner.query(
          `insert into admin_audit_events(actor_staff_id,action,target_kind,reason,request_id,outcome,created_at)
           values ($1,'audit:allowed','route','Allowed fixture.',$2,'allowed',$4),
                  ($1,'audit:denied','route','Denied fixture.',$3,'denied',$4)`,
          [staffId, randomUUID(), randomUUID(), beforeCutoff],
        );
      } finally {
        await owner.end();
      }

      const first = await reconcileAdminAudit(
        databaseUrl!,
        cutoff.getTime(),
        pgPoolFactory,
      );
      const replay = await reconcileAdminAudit(
        databaseUrl!,
        cutoff.getTime(),
        pgPoolFactory,
      );
      expect(replay).toEqual(first);
      expect(first).toMatchObject({
        cutoff_at: expect.any(String),
        event_count: expect.any(Number),
        denied_count: expect.any(Number),
        chain_digest: expect.stringMatching(/^[0-9a-f]{64}$/),
      });
      expect((first?.event_count as number) >= 2).toBe(true);
      expect((first?.denied_count as number) >= 1).toBe(true);

      const verifier = await ownerClient();
      try {
        await verifier.query("set role ritual_runtime");
        await expect(
          verifier.query("select * from admin_audit_checkpoints"),
        ).rejects.toMatchObject({ code: "42501" });
        await expect(
          verifier.query(
            "select ritual_private.record_admin_audit_checkpoint(now())",
          ),
        ).rejects.toMatchObject({ code: "42501" });
        await verifier.query("reset role");

        await verifier.query("set role ritual_audit_reconciler");
        await expect(
          verifier.query("select * from admin_audit_events"),
        ).rejects.toMatchObject({ code: "42501" });
        expect(
          (
            await verifier.query(
              "select event_count,denied_count,chain_digest from admin_audit_checkpoints where cutoff_at=$1",
              [cutoff],
            )
          ).rowCount,
        ).toBe(1);
        await verifier.query("reset role");

        await expect(
          verifier.query(
            "update admin_audit_checkpoints set event_count=event_count+1 where cutoff_at=$1",
            [cutoff],
          ),
        ).rejects.toMatchObject({ code: "55000" });
      } finally {
        await verifier.end();
      }
    });
  },
);
