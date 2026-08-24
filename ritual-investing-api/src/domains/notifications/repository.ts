import type { PoolClient } from "@neondatabase/serverless";

import {
  withScopedRuntimeClient,
  type DatabasePoolFactory,
} from "../../db/client.ts";
import { createRequestDatabaseContext } from "../../db/request-context.ts";
import { enqueueOutbox } from "../../jobs/outbox.ts";
import { sha256TextHex as digest } from "../../security/sha256.ts";
import type { MemberContext } from "../accounts/repository.ts";
import type {
  ContentReportCreate,
  DeviceCreate,
  Notification,
  NotificationPreferences,
  NotificationPreferencesPatch,
} from "./schemas.ts";
import { protectPushToken } from "./service.ts";

export interface NotificationRepository {
  getPreferences(member: MemberContext): Promise<NotificationPreferences>;
  patchPreferences(
    member: MemberContext,
    patch: NotificationPreferencesPatch,
    version: number,
  ): Promise<NotificationPreferences>;
  registerDevice(
    member: MemberContext,
    input: DeviceCreate,
    encryptionKey: string,
    idempotencyKey: string,
  ): Promise<{
    id: string;
    platform: "ios" | "android";
    status: "active" | "revoked";
  }>;
  revokeDevice(member: MemberContext, id: string): Promise<boolean>;
  list(
    member: MemberContext,
    input: { read: "all" | "read" | "unread"; limit: number; after?: string },
  ): Promise<{ items: Notification[]; next: string | null }>;
  markRead(
    member: MemberContext,
    id: string,
    read: boolean,
  ): Promise<Notification | null>;
  markAllRead(
    member: MemberContext,
    before: string | undefined,
    idempotencyKey: string,
  ): Promise<number>;
  report(
    member: MemberContext,
    input: ContentReportCreate,
    idempotencyKey: string,
  ): Promise<{ id: string; status: "received" }>;
}

export class NotificationConflictError extends Error {
  constructor(code: "idempotency_conflict" | "version_conflict") {
    super(code);
    this.name = "NotificationConflictError";
  }
}
export class NotificationContentNotFoundError extends Error {}

const contextFor = (member: MemberContext) =>
  createRequestDatabaseContext({
    accountId: member.accountId,
    tenantId: member.tenantId,
    accountStatus: member.accountStatus,
    tenantStatus: member.tenantStatus,
    revocationEpoch: member.revocationEpoch,
    principal: member.subject,
  });
const preferences = (row: {
  daily_ritual: boolean;
  weekly_recap: boolean;
  moon_cycle: boolean;
  quiet_hours: NotificationPreferences["quiet_hours"];
  version: number;
}): NotificationPreferences => row;
type NotificationRow = Omit<Notification, "scheduled_at" | "read_at"> & {
  scheduled_at: Date | null;
  read_at: Date | null;
};
const notification = (row: NotificationRow): Notification => ({
  ...row,
  scheduled_at: row.scheduled_at?.toISOString() ?? null,
  read_at: row.read_at?.toISOString() ?? null,
});

export function createPostgresNotificationRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): NotificationRepository {
  const scoped = <T>(
    member: MemberContext,
    fn: (client: PoolClient) => Promise<T>,
  ) =>
    withScopedRuntimeClient(databaseUrl, contextFor(member), fn, poolFactory);
  return {
    getPreferences: (member) =>
      scoped(member, async (client) => {
        const result = await client.query(
          `select daily_ritual,weekly_recap,moon_cycle,quiet_hours,version from notification_preferences where tenant_id=$1`,
          [member.tenantId],
        );
        return preferences(result.rows[0] as never);
      }),
    patchPreferences: (member, patch, version) =>
      scoped(member, async (client) => {
        const result = await client.query(
          `update notification_preferences set daily_ritual=coalesce($2,daily_ritual),weekly_recap=coalesce($3,weekly_recap),moon_cycle=coalesce($4,moon_cycle),quiet_hours=coalesce($5::jsonb,quiet_hours),version=version+1 where tenant_id=$1 and version=$6 returning daily_ritual,weekly_recap,moon_cycle,quiet_hours,version`,
          [
            member.tenantId,
            patch.daily_ritual ?? null,
            patch.weekly_recap ?? null,
            patch.moon_cycle ?? null,
            patch.quiet_hours === undefined
              ? null
              : JSON.stringify(patch.quiet_hours),
            version,
          ],
        );
        if (result.rows[0] === undefined)
          throw new NotificationConflictError("version_conflict");
        return preferences(result.rows[0] as never);
      }),
    registerDevice: async (member, input, encryptionKey, idempotencyKey) => {
      const protectedToken = await protectPushToken(
        input.push_token,
        encryptionKey,
      );
      return scoped(member, async (client) => {
        const requestHash = await digest(
          `${input.platform}:${protectedToken.tokenHash}`,
        );
        let result;
        try {
          result = await client.query<{ id: string }>(
            `select ritual_private.register_notification_device($1,$2,$3,$4,$5,$6) id`,
            [
              member.tenantId,
              input.platform,
              protectedToken.tokenCiphertext,
              protectedToken.tokenHash,
              idempotencyKey,
              requestHash,
            ],
          );
        } catch (error) {
          if (
            error instanceof Error &&
            error.message.includes("idempotency_conflict")
          )
            throw new NotificationConflictError("idempotency_conflict");
          throw error;
        }
        const device = await client.query<{ status: "active" | "revoked" }>(
          "select status from device_installations where tenant_id=$1 and id=$2",
          [member.tenantId, result.rows[0]!.id],
        );
        return {
          id: result.rows[0]!.id,
          platform: input.platform,
          status: device.rows[0]!.status,
        };
      });
    },
    revokeDevice: (member, id) =>
      scoped(
        member,
        async (client) =>
          (
            await client.query(
              `update device_installations set status='revoked',push_token_ciphertext='revoked' where tenant_id=$1 and id=$2 and status='active'`,
              [member.tenantId, id],
            )
          ).rowCount === 1,
      ),
    list: (member, input) =>
      scoped(member, async (client) => {
        const result = await client.query<NotificationRow>(
          `select id,kind,title,body,deep_link,scheduled_at,read_at from notifications where tenant_id=$1 and ($2='all' or ($2='read' and read_at is not null) or ($2='unread' and read_at is null)) and ($3::uuid is null or id<$3) order by id desc limit $4`,
          [member.tenantId, input.read, input.after ?? null, input.limit + 1],
        );
        return {
          items: result.rows.slice(0, input.limit).map(notification),
          next:
            result.rows.length > input.limit
              ? result.rows[input.limit - 1]!.id
              : null,
        };
      }),
    markRead: (member, id, read) =>
      scoped(member, async (client) => {
        const row = (
          await client.query<NotificationRow>(
            `update notifications set read_at=case when $3 then coalesce(read_at,now()) else null end where tenant_id=$1 and id=$2 returning id,kind,title,body,deep_link,scheduled_at,read_at`,
            [member.tenantId, id, read],
          )
        ).rows[0];
        return row === undefined ? null : notification(row);
      }),
    markAllRead: (member, before, idempotencyKey) =>
      scoped(member, async (client) => {
        const requestHash = await digest(`read-all:${before ?? "now"}:v1`);
        const created = await client.query(
          `insert into member_command_receipts(tenant_id,operation,idempotency_key,request_hash,response) values ($1,'notifications.read-all',$2,$3,'{"updated_count":-1}'::jsonb) on conflict do nothing`,
          [member.tenantId, idempotencyKey, requestHash],
        );
        const receipt = (
          await client.query<{
            request_hash: string;
            response: { updated_count: number };
          }>(
            `select request_hash,response from member_command_receipts where tenant_id=$1 and operation='notifications.read-all' and idempotency_key=$2 for update`,
            [member.tenantId, idempotencyKey],
          )
        ).rows[0]!;
        if (receipt.request_hash !== requestHash)
          throw new NotificationConflictError("idempotency_conflict");
        if (created.rowCount === 0 || receipt.response.updated_count >= 0)
          return receipt.response.updated_count;
        const updated = await client.query(
          `with bounded as (select id from notifications where tenant_id=$1 and read_at is null and ($2::timestamptz is null or scheduled_at<=$2) order by id limit 100 for update) update notifications n set read_at=now() from bounded b where n.tenant_id=$1 and n.id=b.id`,
          [member.tenantId, before ?? null],
        );
        const count = updated.rowCount ?? 0;
        await client.query(
          `update member_command_receipts set response=jsonb_build_object('updated_count',$3) where tenant_id=$1 and operation='notifications.read-all' and idempotency_key=$2`,
          [member.tenantId, idempotencyKey, count],
        );
        return count;
      }),
    report: (member, input, idempotencyKey) =>
      scoped(member, async (client) => {
        const targetKind =
          input.target_kind === "codex" ? "asset_codex" : input.target_kind;
        const found = await client.query<{ id: string }>(
          `select id from editorial_items where id=$1 and kind=$2 and status='published'`,
          [input.target_id, targetKind],
        );
        if (found.rows[0] === undefined)
          throw new NotificationContentNotFoundError();
        const requestHash = await digest(JSON.stringify(input));
        const candidate = crypto.randomUUID();
        await client.query(
          `insert into member_command_receipts(tenant_id,operation,idempotency_key,request_hash,response) values ($1,'content-report.create',$2,$3,jsonb_build_object('report_id',$4::uuid)) on conflict do nothing`,
          [member.tenantId, idempotencyKey, requestHash, candidate],
        );
        const receipt = (
          await client.query<{
            request_hash: string;
            response: { report_id: string };
          }>(
            `select request_hash,response from member_command_receipts where tenant_id=$1 and operation='content-report.create' and idempotency_key=$2 for update`,
            [member.tenantId, idempotencyKey],
          )
        ).rows[0]!;
        if (receipt.request_hash !== requestHash)
          throw new NotificationConflictError("idempotency_conflict");
        const id = receipt.response.report_id;
        const result = await client.query<{ id: string }>(
          `insert into content_reports(id,tenant_id,target_kind,target_id,reason_code,detail) values ($1,$2,$3,$4,$5,$6) on conflict (id) do nothing returning id`,
          [
            id,
            member.tenantId,
            input.target_kind,
            input.target_id,
            input.reason_code,
            input.detail ?? null,
          ],
        );
        if (result.rows[0] === undefined)
          return { id, status: "received" as const };
        await enqueueOutbox(client, {
          topic: "content-report.created",
          aggregateKind: "content-report",
          aggregateId: id,
          aggregateVersion: 1,
          tenantId: member.tenantId,
          resetGeneration: 0,
          deletionGeneration: 0,
          dedupeKey: id,
          payload: { report_id: id },
        });
        return { id, status: "received" as const };
      }),
  };
}
