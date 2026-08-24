import { randomUUID } from "node:crypto";

import { beforeAll, describe, expect, it } from "vitest";

import {
  createPostgresSimulationRepository,
  simulationHashForTesting,
  SimulationInProgressError,
} from "../../src/domains/simulation/repository.ts";
import {
  createSimulationFixture,
  ownerQuery,
  pgPoolFactory,
  type SimulationFixture,
} from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

describe.skipIf(databaseUrl === undefined)(
  "simulation command PostgreSQL lease recovery",
  () => {
    let fixture: SimulationFixture;

    beforeAll(async () => {
      fixture = await createSimulationFixture(databaseUrl!);
    });

    it("takes over an expired claim after a worker crash", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const key = `expired-${randomUUID()}`;
      const input = {
        source_id: fixture.sourceId,
        amount: { minor_units: 2_000, currency: "USD" as const },
      };
      const requestHash = await simulationHashForTesting({
        portfolio_id: fixture.portfolioId,
        ...input,
      });
      await ownerQuery(
        databaseUrl!,
        `insert into idempotency_records(
           tenant_id,reset_generation,operation,idempotency_key,request_hash,state,
           claim_owner,lease_until,expires_at
         ) values ($1,1,'portfolio.contribution',$2,$3,'processing','dead-worker',
           now()-interval '1 second',now()+interval '1 day')`,
        [fixture.tenantId, key, requestHash],
      );

      const result = await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        input,
        key,
      );
      expect(result.status).toBe("committed");
      const record = await ownerQuery<{
        state: string;
        lease_until: Date | null;
      }>(
        databaseUrl!,
        `select state,lease_until from idempotency_records
         where tenant_id=$1 and idempotency_key=$2`,
        [fixture.tenantId, key],
      );
      expect(record.rows[0]).toMatchObject({
        state: "completed",
        lease_until: null,
      });
    });

    it("does not steal an unexpired claim", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const key = `active-${randomUUID()}`;
      const input = {
        source_id: fixture.sourceId,
        amount: { minor_units: 2_001, currency: "USD" as const },
      };
      const requestHash = await simulationHashForTesting({
        portfolio_id: fixture.portfolioId,
        ...input,
      });
      await ownerQuery(
        databaseUrl!,
        `insert into idempotency_records(
           tenant_id,reset_generation,operation,idempotency_key,request_hash,state,
           claim_owner,lease_until,expires_at
         ) values ($1,1,'portfolio.contribution',$2,$3,'processing','live-worker',
           now()+interval '5 minutes',now()+interval '1 day')`,
        [fixture.tenantId, key, requestHash],
      );

      await expect(
        repository.contribute(fixture.context, fixture.portfolioId, input, key),
      ).rejects.toBeInstanceOf(SimulationInProgressError);
    });

    it("replays a committed response after the caller loses it", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      const key = `lost-response-${randomUUID()}`;
      const input = {
        source_id: fixture.sourceId,
        amount: { minor_units: 3_000, currency: "USD" as const },
      };
      const first = await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        input,
        key,
      );
      const replay = await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        input,
        key,
      );
      expect(replay).toEqual(first);
      const count = await ownerQuery<{ count: string }>(
        databaseUrl!,
        `select count(*)::text count from ledger_transactions transaction
         join simulation_commands command on command.tenant_id=transaction.tenant_id
           and command.id=transaction.command_id
         join idempotency_records record on record.tenant_id=command.tenant_id
           and record.id=command.idempotency_id
         where transaction.tenant_id=$1 and record.idempotency_key=$2`,
        [fixture.tenantId, key],
      );
      expect(count.rows[0]?.count).toBe("1");
    });
  },
);
