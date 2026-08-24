import { Pool } from "@neondatabase/serverless";

import { sessionBootstrapDataSchema, type SessionBootstrapData } from "./schemas.ts";

export interface SessionRepository {
  bootstrap(verifiedSubject: string): Promise<SessionBootstrapData>;
}

export class InactiveBootstrapPrincipalError extends Error {
  constructor() {
    super("inactive_bootstrap_principal");
    this.name = "InactiveBootstrapPrincipalError";
  }
}

type BootstrapRow = {
  account_id: string;
  account_status: "active";
  display_name: string;
  locale: string;
  theme_mode: "system" | "light" | "dark";
  ritual_mode: "tarot" | "astrology";
  timezone: string;
  preferences_version: number;
  current_step: string;
  completed_steps: string[];
  onboarding_version: number;
  plan_code: string;
  entitlement_status: "active";
  portfolio_id: string;
  portfolio_name: string;
  portfolio_currency: "USD";
  portfolio_status: "active";
  portfolio_version: number;
  server_time: Date | string;
};

export function createPostgresSessionRepository(databaseUrl: string): SessionRepository {
  return {
    async bootstrap(verifiedSubject) {
      const pool = new Pool({ connectionString: databaseUrl, max: 1 });
      let client;
      try {
        client = await pool.connect();
        await client.query("begin");
        await client.query("set local role ritual_bootstrap");
        const result = await client.query<BootstrapRow>(
          "select * from ritual_private.bootstrap_member_account($1)",
          [verifiedSubject],
        );
        const row = result.rows[0];
        if (result.rows.length !== 1 || row === undefined) {
          throw new Error("invalid_bootstrap_result");
        }
        const snapshot = sessionBootstrapDataSchema.parse({
          account: { id: row.account_id, status: row.account_status },
          profile: { display_name: row.display_name, locale: row.locale },
          preferences: {
            theme_mode: row.theme_mode,
            ritual_mode: row.ritual_mode,
            timezone: row.timezone,
            locale: row.locale,
            version: Number(row.preferences_version),
          },
          onboarding: {
            current_step: row.current_step,
            completed_steps: row.completed_steps,
            version: Number(row.onboarding_version),
          },
          entitlement: { plan_code: row.plan_code, status: row.entitlement_status },
          default_portfolio: {
            id: row.portfolio_id,
            name: row.portfolio_name,
            currency: row.portfolio_currency,
            status: row.portfolio_status,
            version: Number(row.portfolio_version),
          },
          server_time: new Date(row.server_time).toISOString(),
          contract_version: "1.0.0",
        });
        await client.query("commit");
        return snapshot;
      } catch (error) {
        await client?.query("rollback").catch(() => undefined);
        if (
          error instanceof Error
          && ["subject_not_eligible", "subject_previously_deleted"].includes(error.message)
        ) {
          throw new InactiveBootstrapPrincipalError();
        }
        throw error;
      } finally {
        client?.release();
        await pool.end();
      }
    },
  };
}
