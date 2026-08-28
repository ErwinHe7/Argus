import type { PoolClient } from "@neondatabase/serverless";

import {
  withScopedRuntimeClient,
  type DatabasePoolFactory,
} from "../../db/client.ts";
import { createRequestDatabaseContext } from "../../db/request-context.ts";
import { enqueueOutbox } from "../../jobs/outbox.ts";
import { sha256TextHex as digest } from "../../security/sha256.ts";
import type { MemberContext } from "../accounts/repository.ts";
import type { DeletionReceipt, PrivacyRequest } from "./schemas.ts";

export class PrivacyConflictError extends Error {
  constructor(
    code:
      | "active_export_exists"
      | "deletion_in_progress"
      | "idempotency_conflict" = "idempotency_conflict",
  ) {
    super(code);
    this.name = "PrivacyConflictError";
  }
}

type PrivacyRow = Omit<
  PrivacyRequest,
  "snapshot_at" | "completed_at" | "expires_at" | "download_link"
> & {
  snapshot_at: Date | null;
  completed_at: Date | null;
  expires_at: Date | null;
};
const view = (row: PrivacyRow): PrivacyRequest => ({
  ...row,
  snapshot_at: row.snapshot_at?.toISOString() ?? null,
  completed_at: row.completed_at?.toISOString() ?? null,
  expires_at: row.expires_at?.toISOString() ?? null,
  download_link: null,
});

export interface PrivacyRepository {
  requestExport(
    member: MemberContext,
    format: "zip",
    idempotencyKey: string,
  ): Promise<PrivacyRequest>;
  getRequest(member: MemberContext, id: string): Promise<PrivacyRequest | null>;
  createDownloadLink(
    member: MemberContext,
    id: string,
    apiOrigin: string,
  ): Promise<{ url: string; expires_at: string } | null>;
  requestDeletion(
    member: MemberContext,
    idempotencyKey: string,
  ): Promise<DeletionReceipt>;
  consumeDownload(
    member: MemberContext,
    id: string,
    token: string,
  ): Promise<string | null>;
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

export function createPostgresPrivacyRepository(
  databaseUrl: string,
  poolFactory?: DatabasePoolFactory,
): PrivacyRepository {
  const scoped = <T>(
    member: MemberContext,
    fn: (client: PoolClient) => Promise<T>,
  ) =>
    withScopedRuntimeClient(databaseUrl, contextFor(member), fn, poolFactory);
  const getRequest = (member: MemberContext, id: string) =>
    scoped(member, async (client) => {
      const row = (
        await client.query<PrivacyRow>(
          `select id,request_type,status,snapshot_at,completed_at,expires_at,failure_code,export_format format from privacy_requests where tenant_id=$1 and id=$2`,
          [member.tenantId, id],
        )
      ).rows[0];
      return row === undefined ? null : view(row);
    });
  return {
    requestExport: async (member, format, idempotencyKey) => {
      const id = await scoped(member, async (client) => {
        const requestHash = await digest(
          `export:${member.tenantId}:${format}:v1`,
        );
        const existing = await client.query<{
          id: string;
          request_hash: string;
        }>(
          `select id,request_hash from privacy_requests where tenant_id=$1 and request_type='export' and idempotency_key=$2 for update`,
          [member.tenantId, idempotencyKey],
        );
        if (existing.rows[0] !== undefined) {
          if (existing.rows[0].request_hash !== requestHash)
            throw new PrivacyConflictError();
          return existing.rows[0].id;
        }
        let created;
        try {
          created = await client.query<{ id: string }>(
            `insert into privacy_requests(tenant_id,request_type,status,snapshot_at,source_sequence,archive_schema_version,verified_at,queued_at,idempotency_key,request_hash,expires_at,export_format) values ($1,'export','queued',statement_timestamp(),coalesce((select max(aggregate_version) from outbox_events where tenant_id=$1),0),1,statement_timestamp(),statement_timestamp(),$2,$3,statement_timestamp()+interval '7 days',$4) returning id`,
            [member.tenantId, idempotencyKey, requestHash, format],
          );
        } catch (error) {
          if (
            [
              "privacy_requests_active_type_unique",
              "privacy_requests_one_active_export",
            ].includes((error as { constraint?: string }).constraint ?? "")
          )
            throw new PrivacyConflictError("active_export_exists");
          throw error;
        }
        const requestId = created.rows[0]!.id;
        await enqueueOutbox(client, {
          topic: "privacy.export.requested",
          aggregateKind: "privacy-request",
          aggregateId: requestId,
          aggregateVersion: 1,
          tenantId: member.tenantId,
          resetGeneration: 0,
          deletionGeneration: 0,
          dedupeKey: requestId,
          payload: { request_id: requestId },
        });
        return requestId;
      });
      return (await getRequest(member, id))!;
    },
    getRequest,
    createDownloadLink: (member, id, apiOrigin) =>
      scoped(member, async (client) => {
        const artifact = (
          await client.query<{ id: string }>(
            `select a.id from privacy_export_artifacts a join privacy_requests r on r.tenant_id=a.tenant_id and r.id=a.request_id where a.tenant_id=$1 and a.request_id=$2 and r.status='completed' and a.publication_state='published' and a.expires_at>now() for update`,
            [member.tenantId, id],
          )
        ).rows[0];
        if (artifact === undefined) return null;
        const token =
          crypto.randomUUID().replaceAll("-", "") +
          crypto.randomUUID().replaceAll("-", "");
        const tokenHash = await digest(token);
        await client.query(
          `update privacy_export_artifacts set link_nonce_hash=$3,link_expires_at=now()+interval '5 minutes',downloaded_at=null where tenant_id=$1 and id=$2`,
          [member.tenantId, artifact.id, tokenHash],
        );
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
        return {
          url: `${apiOrigin}/v1/me/privacy/exports/${id}/download?token=${token}`,
          expires_at: expiresAt,
        };
      }),
    requestDeletion: async (member, idempotencyKey) => {
      try {
        return await scoped(member, async (client) => {
          const requestHash = await digest(`delete:${member.tenantId}:v1`);
          const replay = await client.query<{
            request_id: string;
            tombstone_id: string;
            effective_at: Date;
            purge_generation: number;
          }>("select * from ritual_private.member_deletion_replay($1,$2)", [
            member.tenantId,
            idempotencyKey,
          ]);
          if (replay.rows[0] !== undefined)
            return {
              request_id: replay.rows[0].request_id,
              tombstone_id: replay.rows[0].tombstone_id,
              status: "queued" as const,
              effective_at: replay.rows[0].effective_at.toISOString(),
              purge_by: new Date(
                replay.rows[0].effective_at.getTime() + 30 * 86400_000,
              ).toISOString(),
              purge_generation: replay.rows[0].purge_generation,
            };
          const subjectHash = await digest(member.subject);
          const tombstone = (
            await client.query<{
              tombstone_id: string;
              effective_at: Date;
              purge_generation: number;
            }>("select * from ritual_private.begin_member_deletion($1,$2)", [
              member.tenantId,
              subjectHash,
            ])
          ).rows[0]!;
          const request = (
            await client.query<{ id: string }>(
              `insert into privacy_requests(tenant_id,request_type,status,verified_at,queued_at,idempotency_key,request_hash,purge_generation) values ($1,'delete','queued',statement_timestamp(),statement_timestamp(),$2,$3,$4) returning id`,
              [
                member.tenantId,
                idempotencyKey,
                requestHash,
                tombstone.purge_generation,
              ],
            )
          ).rows[0]!;
          await enqueueOutbox(client, {
            topic: "privacy.deletion.requested",
            aggregateKind: "deletion-tombstone",
            aggregateId: tombstone.tombstone_id,
            aggregateVersion: tombstone.purge_generation,
            tenantId: member.tenantId,
            resetGeneration: 0,
            deletionGeneration: tombstone.purge_generation,
            dedupeKey: tombstone.tombstone_id,
            payload: {
              tombstone_id: tombstone.tombstone_id,
              privacy_request_id: request.id,
            },
          });
          return {
            request_id: request.id,
            tombstone_id: tombstone.tombstone_id,
            status: "queued" as const,
            effective_at: tombstone.effective_at.toISOString(),
            purge_by: new Date(
              tombstone.effective_at.getTime() + 30 * 86400_000,
            ).toISOString(),
            purge_generation: tombstone.purge_generation,
          };
        });
      } catch (error) {
        if (
          error instanceof Error &&
          error.message.includes("deletion_in_progress")
        )
          throw new PrivacyConflictError("deletion_in_progress");
        throw error;
      }
    },
    consumeDownload: (member, id, token) =>
      scoped(member, async (client) => {
        const tenant = await client.query<{ status: string }>(
          `select status from tenants where id=$1 for update`,
          [member.tenantId],
        );
        if (tenant.rows[0]?.status !== "active") return null;
        const artifact = (
          await client.query<{
            id: string;
            r2_key: string;
            link_nonce_hash: string;
          }>(
            `select a.id,a.r2_key,a.link_nonce_hash from privacy_export_artifacts a join privacy_requests r on r.tenant_id=a.tenant_id and r.id=a.request_id where a.tenant_id=$1 and a.request_id=$2 and r.status='completed' and a.publication_state='published' and a.expires_at>now() and a.link_expires_at>now() and a.downloaded_at is null and a.link_nonce_hash is not null for update`,
            [member.tenantId, id],
          )
        ).rows[0];
        if (artifact === undefined) return null;
        const actual = await digest(token);
        let difference = actual.length ^ artifact.link_nonce_hash.length;
        for (
          let index = 0;
          index < Math.max(actual.length, artifact.link_nonce_hash.length);
          index += 1
        )
          difference |=
            (actual.charCodeAt(index) || 0) ^
            (artifact.link_nonce_hash.charCodeAt(index) || 0);
        if (difference !== 0) return null;
        await client.query(
          `update privacy_export_artifacts set downloaded_at=now(),link_nonce_hash=null,link_expires_at=null where tenant_id=$1 and id=$2`,
          [member.tenantId, artifact.id],
        );
        return artifact.r2_key;
      }),
  };
}

export { createSupabasePrivacyRepository } from "../../db/supabase-repositories.ts";
