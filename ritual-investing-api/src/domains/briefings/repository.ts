import type { PoolClient } from "@neondatabase/serverless";

import {
  withScopedRuntimeClient,
  type DatabasePoolFactory,
} from "../../db/client.ts";
import { createRequestDatabaseContext } from "../../db/request-context.ts";
import type { MemberContext } from "../accounts/repository.ts";
import type { BriefingDetail, BriefingSummary } from "./schemas.ts";

export interface BriefingRepository {
  list(
    member: MemberContext,
    input: {
      type?: "daily" | "weekly" | "moon_cycle";
      periodStart?: string;
      periodEnd?: string;
      limit: number;
      afterPeriod?: string;
      afterId?: string;
    },
  ): Promise<{
    items: BriefingSummary[];
    next: { period: string; id: string } | null;
  }>;
  daily(
    member: MemberContext,
    localDate: string,
  ): Promise<BriefingDetail | null>;
  get(member: MemberContext, id: string): Promise<BriefingDetail | null>;
  markRead(
    member: MemberContext,
    id: string,
    read: boolean,
  ): Promise<BriefingSummary | null>;
}

const contextFor = (member: MemberContext) =>
  createRequestDatabaseContext({
    accountId: member.accountId,
    tenantId: member.tenantId,
    accountStatus: member.accountStatus,
    tenantStatus: member.tenantStatus,
    revocationEpoch: member.revocationEpoch,
    principal: member.subject,
  });

type BriefingRow = {
  id: string;
  briefing_type: "daily" | "weekly" | "moon_cycle";
  period_start: string;
  period_end: string;
  generation: number;
  source_sequence: string | number;
  generated_at: Date;
  read_at: Date | null;
};

function summary(row: BriefingRow): BriefingSummary {
  return {
    ...row,
    source_sequence: Number(row.source_sequence),
    generated_at: row.generated_at.toISOString(),
    read_at: row.read_at?.toISOString() ?? null,
  };
}

export function createPostgresBriefingRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): BriefingRepository {
  const scoped = <T>(
    member: MemberContext,
    fn: (client: PoolClient) => Promise<T>,
  ) =>
    withScopedRuntimeClient(databaseUrl, contextFor(member), fn, poolFactory);
  const get = (member: MemberContext, id: string) =>
    scoped(member, async (client) => {
      const head = await client.query<BriefingRow>(
        `select id,briefing_type,period_start::text,period_end::text,generation,
                source_sequence,generated_at,read_at
           from briefings where tenant_id=$1 and id=$2 and is_current`,
        [member.tenantId, id],
      );
      const row = head.rows[0];
      if (row === undefined) return null;
      const sections = await client.query<{
        section_type: string;
        ordinal: number;
        payload: Record<string, unknown>;
        schema_version: number;
      }>(
        `select section_type,ordinal,payload,schema_version
           from briefing_sections where tenant_id=$1 and briefing_id=$2
          order by ordinal`,
        [member.tenantId, id],
      );
      return { ...summary(row), sections: sections.rows };
    });
  return {
    list: (member, input) =>
      scoped(member, async (client) => {
        const result = await client.query<BriefingRow>(
          `select id,briefing_type,period_start::text,period_end::text,generation,
                  source_sequence,generated_at,read_at
             from briefings where tenant_id=$1 and is_current
              and ($2::text is null or briefing_type=$2)
              and ($3::date is null or period_end>=$3)
              and ($4::date is null or period_start<=$4)
              and ($5::date is null or (period_end,id)<($5,$6::uuid))
            order by period_end desc,id desc limit $7`,
          [
            member.tenantId,
            input.type ?? null,
            input.periodStart ?? null,
            input.periodEnd ?? null,
            input.afterPeriod ?? null,
            input.afterId ?? null,
            input.limit + 1,
          ],
        );
        const items = result.rows.slice(0, input.limit).map(summary);
        const tail =
          result.rows.length > input.limit
            ? result.rows[input.limit - 1]
            : undefined;
        return {
          items,
          next:
            tail === undefined
              ? null
              : { period: tail.period_end, id: tail.id },
        };
      }),
    daily: async (member, localDate) => {
      const id = await scoped(member, async (client) => {
        const result = await client.query<{ id: string }>(
          `select id from briefings
            where tenant_id=$1 and briefing_type='daily' and period_start=$2 and is_current
            order by generation desc limit 1`,
          [member.tenantId, localDate],
        );
        return result.rows[0]?.id;
      });
      return id === undefined ? null : get(member, id);
    },
    get,
    markRead: (member, id, read) =>
      scoped(member, async (client) => {
        const result = await client.query<BriefingRow>(
          `update briefings set read_at=case when $3 then coalesce(read_at,now()) else null end
            where tenant_id=$1 and id=$2 and is_current
            returning id,briefing_type,period_start::text,period_end::text,generation,
                      source_sequence,generated_at,read_at`,
          [member.tenantId, id, read],
        );
        const row = result.rows[0];
        return row === undefined ? null : summary(row);
      }),
  };
}

export { createSupabaseBriefingRepository } from "../../db/supabase-repositories.ts";
