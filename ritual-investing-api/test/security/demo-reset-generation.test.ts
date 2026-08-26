import { randomUUID } from "node:crypto";

import { beforeAll, describe, expect, it } from "vitest";

import { createPostgresSimulationRepository } from "../../src/domains/simulation/repository.ts";
import {
  createSimulationFixture,
  ownerQuery,
  pgPoolFactory,
  type SimulationFixture,
} from "../helpers/simulation-postgres.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;

describe.skipIf(databaseUrl === undefined)(
  "demo reset generation fencing",
  () => {
    let fixture: SimulationFixture;

    beforeAll(async () => {
      fixture = await createSimulationFixture(databaseUrl!);
    });

    it("invalidates frozen work by generation and replays one reset", async () => {
      const repository = createPostgresSimulationRepository(
        databaseUrl!,
        pgPoolFactory,
      );
      await repository.contribute(
        fixture.context,
        fixture.portfolioId,
        {
          source_id: fixture.sourceId,
          amount: { minor_units: 10_000, currency: "USD" },
        },
        `seed-${randomUUID()}`,
      );
      const portfolio = await repository.getPortfolio(
        fixture.context,
        fixture.portfolioId,
      );
      const preview = await repository.previewOrder(
        fixture.context,
        fixture.portfolioId,
        {
          asset_id: fixture.assetId,
          side: "buy",
          notional: { minor_units: 1_000, currency: "USD" },
        },
      );
      const resetKey = `reset-${randomUUID()}`;
      const first = await repository.resetDemo(
        fixture.context,
        fixture.seedVersion,
        resetKey,
      );
      const replay = await repository.resetDemo(
        fixture.context,
        fixture.seedVersion,
        resetKey,
      );
      expect(replay).toEqual(first);
      expect(first.reset_generation).toBe(2);
      await expect(
        repository.commitOrder(
          fixture.context,
          fixture.portfolioId,
          { preview_id: preview.id, portfolio_version: portfolio!.version },
          `old-${randomUUID()}`,
        ),
      ).rejects.toThrow();
      const current = await repository.listPortfolios(fixture.context, 20);
      expect(current.items).toHaveLength(1);
      expect(current.items[0]?.id).not.toBe(fixture.portfolioId);
      const session = await ownerQuery<{
        portfolio_id: string;
        plan_code: string;
      }>(
        databaseUrl!,
        `select portfolio_id,plan_code
         from ritual_private.bootstrap_member_account($1)`,
        [fixture.context.subject],
      );
      expect(session.rows[0]).toMatchObject({
        portfolio_id: current.items[0]?.id,
        plan_code: "demo",
      });
      const state = await ownerQuery<{
        reset_generation: number;
        events: string;
        current_defaults: string;
      }>(
        databaseUrl!,
        `select state.reset_generation,
           (select count(*) from demo_reset_events where tenant_id=state.tenant_id)::text events,
           (select count(*) from demo_portfolios portfolio
             where portfolio.tenant_id=state.tenant_id
               and portfolio.reset_generation=state.reset_generation
               and portfolio.is_default)::text current_defaults
         from tenant_demo_states state where state.tenant_id=$1`,
        [fixture.tenantId],
      );
      expect(state.rows[0]).toEqual({
        reset_generation: 2,
        events: "1",
        current_defaults: "1",
      });
    });
  },
);
