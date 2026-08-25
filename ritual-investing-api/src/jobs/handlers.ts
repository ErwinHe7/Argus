import { z } from "zod";

import {
  notificationDeliveryEnabled,
  type Bindings,
} from "../config/env.ts";
import { inspectQuarantinedObject } from "../domains/media/service.ts";
import { unprotectPushToken } from "../domains/notifications/service.ts";
import {
  buildDeletionDenyEntry,
  buildStreamingPrivacyZip,
  type StreamingExportCollection,
  verifyDeletionDenyEntry,
} from "../domains/privacy/service.ts";
import { sha256TextHex as hash } from "../security/sha256.ts";
import { enqueueOutbox } from "./outbox.ts";
import type { ConsumerEffect, OutboxEvent } from "./consumer-receipts.ts";
import type { QueueWorkMessage } from "./queue-consumer.ts";

const payloadIds = z
  .object({
    request_id: z.string().uuid().optional(),
    privacy_request_id: z.string().uuid().optional(),
    tombstone_id: z.string().uuid().optional(),
    notification_id: z.string().uuid().optional(),
    media_id: z.string().uuid().optional(),
    actor_staff_id: z.string().uuid().optional(),
    local_date: z.string().date().optional(),
    briefing_type: z.enum(["daily", "weekly", "moon_cycle"]).optional(),
    plan_id: z.string().uuid().optional(),
    scheduled_for: z.string().datetime({ offset: true }).optional(),
    reset_generation: z.number().int().positive().optional(),
    artifact_id: z.string().uuid().optional(),
  })
  .strict();

async function dependencyFetch(
  fetcher: Fetcher,
  input: string,
  init: RequestInit,
  failureCode: string,
): Promise<Response> {
  try {
    return await fetcher.fetch(input, {
      ...init,
      signal: AbortSignal.timeout(10_000),
    });
  } catch {
    throw new Error(failureCode);
  }
}

function briefingBuilder(): ConsumerEffect {
  return async (client, event) => {
    if (event.tenant_id === null) return "deleted";
    const payload = payloadIds.parse(event.payload);
    const type = payload.briefing_type ?? "daily";
    const periodStart = payload.local_date;
    if (periodStart === undefined) throw new Error("invalid_event_payload");
    const current = await client.query<{ id: string; generation: number }>(
      `select id,generation from briefings where tenant_id=$1 and briefing_type=$2 and period_start=$3 and is_current for update`,
      [event.tenant_id, type, periodStart],
    );
    if ((current.rows[0]?.generation ?? 0) >= event.aggregate_version)
      return "briefing-stale";
    if (current.rows[0] !== undefined)
      await client.query(
        `update briefings set is_current=false where tenant_id=$1 and id=$2`,
        [event.tenant_id, current.rows[0].id],
      );
    const sourceHash = await hash(`${event.id}:${event.aggregate_version}`);
    const inserted = await client.query<{ id: string }>(
      `insert into briefings(tenant_id,briefing_type,period_start,period_end,generation,supersedes_id,source_hash,source_sequence,reset_generation,deletion_generation,generated_at,is_current) values ($1,$2,$3,$3,$4,$5,$6,$4,$7,$8,now(),true) returning id`,
      [
        event.tenant_id,
        type,
        periodStart,
        event.aggregate_version,
        current.rows[0]?.id ?? null,
        sourceHash,
        event.reset_generation,
        event.deletion_generation,
      ],
    );
    await client.query(
      `insert into briefing_sections(tenant_id,briefing_id,section_type,ordinal,payload,schema_version) values ($1,$2,'summary',1,$3::jsonb,1)`,
      [
        event.tenant_id,
        inserted.rows[0]!.id,
        JSON.stringify({
          source_sequence: event.aggregate_version,
          disclosure:
            "Generated from recorded Demo activity; not financial advice.",
        }),
      ],
    );
    await enqueueOutbox(client, {
      topic: `briefing.${type}.generated`,
      aggregateKind: "briefing",
      aggregateId: inserted.rows[0]!.id,
      aggregateVersion: event.aggregate_version,
      tenantId: event.tenant_id,
      resetGeneration: event.reset_generation,
      deletionGeneration: event.deletion_generation,
      dedupeKey: inserted.rows[0]!.id,
      payload: { briefing_id: inserted.rows[0]!.id },
    });
    return sourceHash;
  };
}

function notificationWriter(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    if (event.tenant_id === null) return "deleted";
    const preference = await client.query<{ allowed: boolean }>(
      `select case when $2='weekly' then weekly_recap when $2='moon_cycle' then moon_cycle else daily_ritual end allowed from notification_preferences where tenant_id=$1`,
      [
        event.tenant_id,
        event.topic.includes("weekly")
          ? "weekly"
          : event.topic.includes("moon")
            ? "moon_cycle"
            : "daily",
      ],
    );
    if (!preference.rows[0]?.allowed) return "preference-disabled";
    const inserted = await client.query<{ id: string }>(
      `insert into notifications(tenant_id,kind,title,body,deep_link,scheduled_at,source_outbox_id,reset_generation,deletion_generation) values ($1,$2,$3,$4,'/briefings',now(),$5,$6,$7) on conflict (tenant_id,source_outbox_id,kind) do update set source_outbox_id=excluded.source_outbox_id returning id`,
      [
        event.tenant_id,
        "briefing_ready",
        "Your Ritual briefing is ready",
        "Open Ritual to view your latest reflection.",
        event.id,
        event.reset_generation,
        event.deletion_generation,
      ],
    );
    const notificationId = inserted.rows[0]!.id;
    if (notificationDeliveryEnabled(environment))
      await enqueueOutbox(client, {
        topic: "notification.delivery.requested",
        aggregateKind: "notification",
        aggregateId: notificationId,
        aggregateVersion: 1,
        tenantId: event.tenant_id,
        resetGeneration: event.reset_generation,
        deletionGeneration: event.deletion_generation,
        dedupeKey: notificationId,
        payload: { notification_id: notificationId },
      });
    return `notification:${event.id}`;
  };
}

function editorialPublisher(): ConsumerEffect {
  return async (client, event) => {
    if (
      event.tenant_id !== null ||
      event.topic !== "editorial.publication.scheduled"
    )
      return "editorial-publication-stale";
    const result = await client.query<{ outcome: string }>(
      "select ritual_private.apply_scheduled_publication($1) outcome",
      [event.id],
    );
    return `editorial-publication:${result.rows[0]?.outcome ?? "stale"}`;
  };
}

function providerCode(
  status: number,
): "accepted" | "invalid_token" | "provider_rejected" {
  if (status === 200 || status === 201 || status === 202 || status === 204)
    return "accepted";
  if (status === 400 || status === 404 || status === 410)
    return "invalid_token";
  return "provider_rejected";
}

function notificationDelivery(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    if (event.tenant_id === null) return "deleted";
    if (
      environment.PUSH_PROVIDER === undefined ||
      environment.PUSH_TOKEN_ENCRYPTION_KEY === undefined
    )
      throw new Error("notification_delivery_unavailable");
    const payload = payloadIds.parse(event.payload);
    const notificationId = payload.notification_id ?? event.aggregate_id;
    const notification = (
      await client.query<{
        id: string;
        title: string;
        body: string;
        deep_link: string | null;
      }>(
        `select id,title,body,deep_link
           from notifications
          where tenant_id=$1 and id=$2 and reset_generation=$3
            and deletion_generation=$4
          for update`,
        [
          event.tenant_id,
          notificationId,
          event.reset_generation,
          event.deletion_generation,
        ],
      )
    ).rows[0];
    if (notification === undefined) return "notification-cancelled";
    const devices = await client.query<{
      id: string;
      push_token_ciphertext: string;
    }>(
      `select id,push_token_ciphertext
         from device_installations
        where tenant_id=$1 and status='active'
        order by id
        for update`,
      [event.tenant_id],
    );
    let delivered = 0;
    for (const device of devices.rows) {
      const token = await unprotectPushToken(
        device.push_token_ciphertext,
        environment.PUSH_TOKEN_ENCRYPTION_KEY,
      );
      const idempotencyKey = await hash(`${event.id}:${device.id}`);
      const response = await dependencyFetch(
        environment.PUSH_PROVIDER,
        "https://push-provider.internal/v1/send",
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "idempotency-key": idempotencyKey,
          },
          body: JSON.stringify({
            token,
            title: notification.title,
            body: notification.body,
            deep_link: notification.deep_link,
          }),
        },
        "notification_provider_unavailable",
      );
      if (response.status === 429)
        throw new Error("notification_provider_rate_limited");
      if (response.status >= 500)
        throw new Error("notification_provider_unavailable");
      const code = providerCode(response.status);
      const status = code === "accepted" ? "sent" : "failed";
      await client.query(
        `insert into notification_deliveries(
           tenant_id,notification_id,installation_id,status,attempt,provider_code,sent_at
         ) values ($1,$2,$3,$4,1,$5,case when $4='sent' then now() end)
         on conflict (tenant_id,notification_id,installation_id,attempt) do nothing`,
        [event.tenant_id, notification.id, device.id, status, code],
      );
      if (code === "invalid_token")
        await client.query(
          `update device_installations set status='revoked',push_token_ciphertext='revoked'
            where tenant_id=$1 and id=$2 and status='active'`,
          [event.tenant_id, device.id],
        );
      if (status === "sent") delivered += 1;
    }
    return `notification-delivered:${delivered}`;
  };
}

function hexadecimal(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function mediaScan(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    if (
      environment.MEDIA_QUARANTINE === undefined ||
      environment.MEDIA_PUBLIC === undefined ||
      environment.MEDIA_SCANNER === undefined ||
      environment.MEDIA_PROCESSOR === undefined
    )
      throw new Error("media_scan_unavailable");
    const payload = payloadIds.parse(event.payload);
    if (
      payload.media_id === undefined ||
      payload.actor_staff_id === undefined ||
      event.aggregate_id !== payload.media_id
    )
      throw new Error("invalid_event_payload");
    const intent = (
      await client.query<{
        id: string;
        actor_staff_id: string;
        r2_key: string;
        expected_mime: string;
        expected_checksum: string;
        status: string;
      }>(
        `select id,actor_staff_id,r2_key,expected_mime,expected_checksum,status
           from media_upload_intents
          where id=$1 and actor_staff_id=$2
          for update`,
        [payload.media_id, payload.actor_staff_id],
      )
    ).rows[0];
    if (intent === undefined) throw new Error("media_intent_missing");
    if (intent.status === "accepted" || intent.status === "rejected")
      return `media-terminal:${intent.status}`;
    if (intent.status !== "scanning")
      throw new Error("media_intent_not_scanning");
    const quarantined = await environment.MEDIA_QUARANTINE.get(intent.r2_key);
    if (
      quarantined === null ||
      quarantined.customMetadata?.upload_intent_id !== intent.id ||
      quarantined.customMetadata?.actor_staff_id !== intent.actor_staff_id
    )
      throw new Error("media_quarantine_mismatch");
    const originalBytes = new Uint8Array(await quarantined.arrayBuffer());
    const scanResponse = await dependencyFetch(
      environment.MEDIA_SCANNER,
      "https://media-scanner.internal/v1/scan",
      {
        method: "POST",
        headers: {
          "content-type": "application/octet-stream",
          "idempotency-key": await hash(`${event.id}:scan`),
        },
        body: originalBytes,
      },
      "media_scanner_unavailable",
    );
    if (!scanResponse.ok) throw new Error("media_scanner_unavailable");
    const scanPayload = (await scanResponse.json().catch(() => ({}))) as {
      result?: unknown;
    };
    if (scanPayload.result !== "clean" && scanPayload.result !== "malicious")
      throw new Error("media_scanner_invalid_response");
    const inspected = await inspectQuarantinedObject(originalBytes, {
      declaredMime: intent.expected_mime,
      expectedChecksum: intent.expected_checksum,
      scanResult: scanPayload.result,
      actorId: payload.actor_staff_id,
      intendedActorId: intent.actor_staff_id,
      uploadIntentId: payload.media_id,
      expectedUploadIntentId: intent.id,
    });
    if (!inspected.validation.ok) {
      await client.query(
        `update media_upload_intents set status='rejected',consumed_at=now()
          where id=$1 and actor_staff_id=$2 and status='scanning'`,
        [intent.id, intent.actor_staff_id],
      );
      await enqueueOutbox(client, {
        topic: "media.quarantine.cleanup",
        aggregateKind: "media-upload-intent",
        aggregateId: intent.id,
        aggregateVersion: event.aggregate_version,
        tenantId: null,
        resetGeneration: 0,
        deletionGeneration: 0,
        dedupeKey: intent.id,
        payload: { media_id: intent.id, actor_staff_id: intent.actor_staff_id },
      });
      return `media-rejected:${inspected.validation.code}`;
    }
    const processed = await dependencyFetch(
      environment.MEDIA_PROCESSOR,
      "https://media-processor.internal/v1/rasterize",
      {
        method: "POST",
        headers: {
          "content-type": intent.expected_mime,
          "idempotency-key": await hash(`${event.id}:process`),
        },
        body: originalBytes,
      },
      "media_processor_unavailable",
    );
    if (!processed.ok) throw new Error("media_processor_unavailable");
    const derivativeBytes = new Uint8Array(await processed.arrayBuffer());
    const derivativeChecksum = hexadecimal(
      new Uint8Array(await crypto.subtle.digest("SHA-256", derivativeBytes)),
    );
    const derivative = await inspectQuarantinedObject(derivativeBytes, {
      declaredMime: intent.expected_mime,
      expectedChecksum: derivativeChecksum,
      scanResult: "clean",
      actorId: payload.actor_staff_id,
      intendedActorId: intent.actor_staff_id,
      uploadIntentId: payload.media_id,
      expectedUploadIntentId: intent.id,
    });
    if (!derivative.validation.ok) {
      await client.query(
        `update media_upload_intents set status='rejected',consumed_at=now()
          where id=$1 and actor_staff_id=$2 and status='scanning'`,
        [intent.id, intent.actor_staff_id],
      );
      await enqueueOutbox(client, {
        topic: "media.quarantine.cleanup",
        aggregateKind: "media-upload-intent",
        aggregateId: intent.id,
        aggregateVersion: event.aggregate_version,
        tenantId: null,
        resetGeneration: 0,
        deletionGeneration: 0,
        dedupeKey: intent.id,
        payload: { media_id: intent.id, actor_staff_id: intent.actor_staff_id },
      });
      return `media-rejected:${derivative.validation.code}`;
    }
    const publishedKey = `media/v1/${intent.id}`;
    await environment.MEDIA_PUBLIC.put(publishedKey, derivativeBytes, {
      httpMetadata: { contentType: intent.expected_mime },
      customMetadata: {
        upload_intent_id: intent.id,
        checksum: derivative.checksum,
      },
    });
    try {
      await client.query(
        `insert into media_assets(
           id,r2_key,mime_type,byte_size,checksum,width,height,quarantine_status,
           scan_result,status,upload_intent_id,actor_staff_id,schema_version,accepted_at
         ) values ($1,$2,$3,$4,$5,$6,$7,'clear','clean','active',$1,$8,1,now())
         on conflict (upload_intent_id) do nothing`,
        [
          intent.id,
          publishedKey,
          intent.expected_mime,
          derivativeBytes.byteLength,
          derivative.checksum,
          derivative.width,
          derivative.height,
          intent.actor_staff_id,
        ],
      );
      const accepted = await client.query(
        `update media_upload_intents set status='accepted',consumed_at=now()
          where id=$1 and actor_staff_id=$2 and status='scanning'`,
        [intent.id, intent.actor_staff_id],
      );
      if (accepted.rowCount !== 1) throw new Error("media_intent_race");
      await enqueueOutbox(client, {
        topic: "media.quarantine.cleanup",
        aggregateKind: "media-upload-intent",
        aggregateId: intent.id,
        aggregateVersion: event.aggregate_version,
        tenantId: null,
        resetGeneration: 0,
        deletionGeneration: 0,
        dedupeKey: intent.id,
        payload: { media_id: intent.id, actor_staff_id: intent.actor_staff_id },
      });
    } catch (error) {
      await environment.MEDIA_PUBLIC.delete(publishedKey).catch(
        () => undefined,
      );
      throw error;
    }
    return `media-accepted:${intent.id}`;
  };
}

function mediaCleanup(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    const payload = payloadIds.parse(event.payload);
    if (
      payload.media_id === undefined ||
      payload.actor_staff_id === undefined ||
      event.aggregate_id !== payload.media_id
    )
      throw new Error("invalid_event_payload");
    if (event.topic === "media.public.cleanup") {
      if (environment.MEDIA_PUBLIC === undefined)
        throw new Error("media_scan_unavailable");
      const asset = (
        await client.query<{ r2_key: string }>(
          `select r2_key from media_assets
            where id=$1 and actor_staff_id=$2 and status='retired'`,
          [payload.media_id, payload.actor_staff_id],
        )
      ).rows[0];
      if (asset === undefined) return "media-cleanup-stale";
      await environment.MEDIA_PUBLIC.delete(asset.r2_key);
      return `media-public-cleanup:${payload.media_id}`;
    }
    if (environment.MEDIA_QUARANTINE === undefined)
      throw new Error("media_scan_unavailable");
    const intent = (
      await client.query<{
        id: string;
        actor_staff_id: string;
        r2_key: string;
        status: string;
      }>(
        `select id,actor_staff_id,r2_key,status
           from media_upload_intents
          where id=$1 and actor_staff_id=$2 and status in ('accepted','rejected')`,
        [payload.media_id, payload.actor_staff_id],
      )
    ).rows[0];
    if (intent === undefined) return "media-cleanup-stale";
    const object = await environment.MEDIA_QUARANTINE.get(intent.r2_key);
    if (object === null) return "media-cleanup-complete";
    if (
      object.customMetadata?.upload_intent_id !== intent.id ||
      object.customMetadata?.actor_staff_id !== intent.actor_staff_id
    )
      throw new Error("media_quarantine_mismatch");
    await environment.MEDIA_QUARANTINE.delete(intent.r2_key);
    return `media-cleanup:${intent.id}`;
  };
}

function moderationTriage(): ConsumerEffect {
  return async (client, event) => {
    if (event.tenant_id === null) return "deleted";
    await client.query(
      `select ritual_private.triage_content_report($1,$2,$3)`,
      [event.id, event.tenant_id, event.aggregate_id],
    );
    return `moderation:${event.aggregate_id}`;
  };
}

function recurringPlanDelivery(): ConsumerEffect {
  return async (client, event) => {
    const payload = payloadIds.parse(event.payload);
    if (
      event.tenant_id === null ||
      payload.plan_id === undefined ||
      payload.scheduled_for === undefined ||
      payload.reset_generation === undefined ||
      event.aggregate_id !== payload.plan_id ||
      event.reset_generation !== payload.reset_generation
    )
      throw new Error("invalid_event_payload");
    const result = await client.query<{ outcome: string }>(
      "select ritual_private.apply_due_recurring_plan_event($1) outcome",
      [event.id],
    );
    return `recurring-plan:${result.rows[0]?.outcome ?? "stale"}`;
  };
}

function privacyExportRetention(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    if (event.tenant_id === null || environment.PRIVACY_EXPORTS === undefined)
      throw new Error("privacy_export_retention_failed");
    const payload = payloadIds.parse(event.payload);
    if (
      payload.artifact_id === undefined ||
      event.aggregate_id !== payload.artifact_id
    )
      throw new Error("invalid_event_payload");
    const artifact = (
      await client.query<{ r2_key: string }>(
        `select r2_key from privacy_export_artifacts
          where tenant_id=$1 and id=$2 and publication_state in ('published','revoked')
            and expires_at<=now() for update`,
        [event.tenant_id, payload.artifact_id],
      )
    ).rows[0];
    if (artifact === undefined) return "retention-stale";
    await environment.PRIVACY_EXPORTS.delete(artifact.r2_key).catch(() => {
      throw new Error("privacy_export_retention_failed");
    });
    await client.query(
      `update privacy_export_artifacts
          set publication_state='deleted',deleted_at=coalesce(deleted_at,now()),
              link_nonce_hash=null,link_expires_at=null
        where tenant_id=$1 and id=$2 and publication_state in ('published','revoked')`,
      [event.tenant_id, payload.artifact_id],
    );
    return `retained:${payload.artifact_id}`;
  };
}

function privacyExport(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    if (event.tenant_id === null || environment.PRIVACY_EXPORTS === undefined)
      throw new Error("privacy_export_unavailable");
    const payload = payloadIds.parse(event.payload);
    if (payload.request_id === undefined)
      throw new Error("invalid_event_payload");
    const request = await client.query<{
      snapshot_at: Date;
      source_sequence: string;
    }>(
      `update privacy_requests request
          set status='processing',snapshot_at=transaction_timestamp(),
              source_sequence=coalesce((
                select max(event.aggregate_version) from outbox_events event
                 where event.tenant_id=request.tenant_id
              ),0)
        where request.tenant_id=$1 and request.id=$2
          and request.request_type='export' and request.status in ('queued','processing')
        returning request.snapshot_at,request.source_sequence`,
      [event.tenant_id, payload.request_id],
    );
    const state = request.rows[0];
    if (state === undefined) return "export-cancelled";
    const collections: StreamingExportCollection[] = [];
    const snapshot = (name: string, sql: string) => {
      collections.push({
        name,
        readPage: async (offset, limit) =>
          (
            await client.query<{ value: unknown }>(
              `select to_jsonb(export_row) value from (${sql}) export_row limit $2 offset $3`,
              [event.tenant_id, limit, offset],
            )
          ).rows.map((row) => row.value),
      });
    };
    snapshot(
      "account",
      `select id,status,created_at,last_seen_at from accounts where tenant_id=$1`,
    );
    snapshot(
      "profile",
      `select display_name,avatar_media_id,locale from profiles where tenant_id=$1`,
    );
    snapshot(
      "preferences",
      `select theme_mode,ritual_mode,timezone,locale,version from preferences where tenant_id=$1`,
    );
    snapshot(
      "onboarding",
      `select current_step,completed_steps,completed_at,version from onboarding_states where tenant_id=$1`,
    );
    snapshot(
      "astrology_profile",
      `select birth_date,derived_profile_code,algorithm_version,enabled_at from astrology_profiles where tenant_id=$1`,
    );
    snapshot(
      "investor_profile",
      `select goal_type,time_horizon,risk_comfort,version from investor_profiles where tenant_id=$1`,
    );
    snapshot(
      "consents",
      `select policy_code,policy_version,decision,recorded_at from consent_records where tenant_id=$1 order by recorded_at,id`,
    );
    snapshot(
      "daily_ritual_assignments",
      `select id,local_date,mode,state,revealed_at,completed_at from daily_ritual_assignments where tenant_id=$1 order by local_date,id`,
    );
    snapshot(
      "saved_assets",
      `select asset_id,source_kind,source_id,saved_at from saved_assets where tenant_id=$1 order by asset_id`,
    );
    snapshot(
      "saved_grimoires",
      `select grimoire_id,revision_id,saved_at from saved_grimoires where tenant_id=$1 order by grimoire_id`,
    );
    snapshot(
      "saved_circle_templates",
      `select template_id,revision_id,saved_at from saved_circle_templates where tenant_id=$1 order by template_id`,
    );
    snapshot(
      "saved_coven_entries",
      `select entry_id,verification_id,saved_at from saved_coven_entries where tenant_id=$1 order by entry_id`,
    );
    snapshot(
      "circles",
      `select id,title,description,source_template_id,source_revision_id,version,archived_at from circles where tenant_id=$1 order by id`,
    );
    snapshot(
      "circle_assets",
      `select id,circle_id,asset_id,ordinal,weight_bps,note from circle_assets where tenant_id=$1 order by circle_id,ordinal,id`,
    );
    snapshot(
      "demo_portfolios",
      `select id,name,currency,status,version,reset_generation,is_default,current_ledger_watermark::text from demo_portfolios where tenant_id=$1 order by id`,
    );
    snapshot(
      "portfolio_target_allocations",
      `select portfolio_id,asset_id,target_bps,version from portfolio_target_allocations where tenant_id=$1 order by portfolio_id,asset_id`,
    );
    snapshot(
      "portfolio_positions",
      `select portfolio_id,asset_id,quantity::text,cost_basis_minor::text,as_of_transaction_id,ledger_watermark::text from portfolio_positions where tenant_id=$1 order by portfolio_id,asset_id`,
    );
    snapshot(
      "portfolio_balance_snapshots",
      `select id,portfolio_id,as_of_transaction_id,projection_generation,as_of,cash_minor::text,market_value_minor::text from portfolio_balance_snapshots where tenant_id=$1 order by portfolio_id,projection_generation`,
    );
    snapshot(
      "demo_funding_sources",
      `select id,fixture_key,display_label,fictional_last4,status,reset_generation from demo_funding_sources where tenant_id=$1 order by id`,
    );
    snapshot(
      "simulation_activity",
      `select id,portfolio_id,command_type,status,rejection_code,committed_at,reset_generation from simulation_commands where tenant_id=$1 order by committed_at,id`,
    );
    snapshot(
      "simulated_orders",
      `select simulated_order.id,simulated_order.portfolio_id,simulated_order.asset_id,simulated_order.status,simulated_order.side,simulated_order.order_type,simulated_order.requested_notional_minor::text,simulated_order.requested_quantity::text,command.committed_at from simulated_orders simulated_order join simulation_commands command on command.tenant_id=simulated_order.tenant_id and command.id=simulated_order.command_id where simulated_order.tenant_id=$1 order by simulated_order.id`,
    );
    snapshot(
      "simulated_order_fills",
      `select fill.id,fill.order_id,fill.quantity::text,fill.price_minor::text,fill.filled_at from simulated_order_fills fill where fill.tenant_id=$1 order by fill.id`,
    );
    snapshot(
      "ledger_transactions",
      `select id,portfolio_id,entry_type,effective_at,description_code,ledger_sequence::text,reset_generation from ledger_transactions where tenant_id=$1 order by ledger_sequence`,
    );
    snapshot(
      "cash_ledger_entries",
      `select id,transaction_id,currency,amount_minor::text from cash_ledger_entries where tenant_id=$1 order by id`,
    );
    snapshot(
      "position_ledger_entries",
      `select id,transaction_id,asset_id,quantity::text,unit_price_minor::text from position_ledger_entries where tenant_id=$1 order by id`,
    );
    snapshot(
      "recurring_plans",
      `select id,portfolio_id,plan_type,amount_minor::text,frequency,next_run_at,last_scheduled_for,status,version,reset_generation from recurring_plans where tenant_id=$1 order by id`,
    );
    snapshot(
      "recurring_plan_allocations",
      `select plan_id,asset_id,weight_bps from recurring_plan_allocations where tenant_id=$1 order by plan_id,asset_id`,
    );
    snapshot(
      "recurring_plan_runs",
      `select id,plan_id,scheduled_for,status,attempted_at,reset_generation from recurring_plan_runs where tenant_id=$1 order by plan_id,scheduled_for`,
    );
    snapshot(
      "rebalance_previews",
      `select id,portfolio_id,input_version,expires_at,status,reset_generation from rebalance_previews where tenant_id=$1 order by id`,
    );
    snapshot(
      "rebalance_preview_trades",
      `select id,preview_id,asset_id,side,quantity::text,notional_minor::text from rebalance_preview_trades where tenant_id=$1 order by preview_id,id`,
    );
    snapshot(
      "intentions",
      `select id,title,target_minor::text,target_date,status,version,currency,portfolio_id,reset_generation,current_projection_generation,current_projection_watermark::text from intentions where tenant_id=$1 order by id`,
    );
    snapshot(
      "projection_runs",
      `select id,intention_id,projection_generation,input_hash,model_version,generated_at,status,ledger_watermark::text,assumptions from projection_runs where tenant_id=$1 order by intention_id,projection_generation`,
    );
    snapshot(
      "projection_points",
      `select run_id,point_date,low_minor::text,mid_minor::text,high_minor::text from projection_points where tenant_id=$1 order by run_id,point_date`,
    );
    snapshot(
      "briefings",
      `select id,briefing_type,period_start,period_end,generation,source_sequence,generated_at,read_at,is_current from briefings where tenant_id=$1 order by id`,
    );
    snapshot(
      "briefing_sections",
      `select id,briefing_id,section_type,ordinal,payload,schema_version from briefing_sections where tenant_id=$1 order by briefing_id,ordinal`,
    );
    snapshot(
      "demo_checkout_sessions",
      `select session.id,plan.code plan_code,session.status,session.expires_at from demo_checkout_sessions session join demo_plans plan on plan.id=session.plan_id where session.tenant_id=$1 order by session.id`,
    );
    snapshot(
      "entitlements",
      `select entitlement.id,plan.code plan_code,entitlement.status,entitlement.source,entitlement.starts_at,entitlement.ends_at,entitlement.version from tenant_entitlements entitlement join demo_plans plan on plan.id=entitlement.plan_id where entitlement.tenant_id=$1 order by entitlement.id`,
    );
    snapshot(
      "entitlement_events",
      `select id,entitlement_id,event_type,occurred_at from entitlement_events where tenant_id=$1 order by occurred_at,id`,
    );
    snapshot(
      "notification_preferences",
      `select daily_ritual,weekly_recap,moon_cycle,quiet_hours,version from notification_preferences where tenant_id=$1`,
    );
    snapshot(
      "devices",
      `select id,platform,status,last_seen_at from device_installations where tenant_id=$1 order by id`,
    );
    snapshot(
      "notifications",
      `select id,kind,title,body,deep_link,scheduled_at,read_at from notifications where tenant_id=$1 order by id`,
    );
    snapshot(
      "notification_deliveries",
      `select id,notification_id,installation_id,status,attempt,provider_code,sent_at from notification_deliveries where tenant_id=$1 order by id`,
    );
    snapshot(
      "content_reports",
      `select id,target_kind,target_id,reason_code,detail,created_at from content_reports where tenant_id=$1 order by id`,
    );
    snapshot(
      "privacy_requests",
      `select id,request_type,status,snapshot_at,archive_schema_version,verified_at,queued_at,completed_at,failure_code from privacy_requests where tenant_id=$1 order by id`,
    );
    const archive = buildStreamingPrivacyZip({
      tenantId: event.tenant_id,
      requestId: payload.request_id,
      snapshotAt: state.snapshot_at.toISOString(),
      sourceSequence: Number(state.source_sequence),
      collections,
      pageSize: 100,
    });
    const key = `privacy-exports/v1/${event.tenant_id}/${payload.request_id}.zip`;
    await environment.PRIVACY_EXPORTS.put(key, archive.body, {
      httpMetadata: { contentType: "application/zip" },
      customMetadata: { schema_version: "2" },
    });
    const { manifestChecksum: checksum } = await archive.completion;
    await client.query(
      `insert into privacy_export_artifacts(tenant_id,request_id,r2_key,manifest_checksum,publication_state,expires_at) values ($1,$2,$3,$4,'published',least(now()+interval '7 days',(select expires_at from privacy_requests where tenant_id=$1 and id=$2))) on conflict (tenant_id,request_id) do update set r2_key=excluded.r2_key,manifest_checksum=excluded.manifest_checksum,publication_state='published',expires_at=excluded.expires_at,revoked_at=null,deleted_at=null`,
      [event.tenant_id, payload.request_id, key, checksum],
    );
    await client.query(
      `update privacy_requests set status='completed',archive_schema_version=2,completed_at=now(),failure_code=null where tenant_id=$1 and id=$2 and status='processing'`,
      [event.tenant_id, payload.request_id],
    );
    return checksum;
  };
}

async function deletePrefix(bucket: R2Bucket, prefix: string): Promise<string> {
  let cursor: string | undefined;
  let checksum = await hash("");
  do {
    const listed = await bucket.list({
      prefix,
      ...(cursor === undefined ? {} : { cursor }),
    });
    const keys = listed.objects.map((object) => object.key).sort();
    if (keys.length > 0) {
      checksum = await hash(`${checksum}\n${keys.join("\n")}`);
      for (const key of keys) await bucket.delete(key);
    }
    cursor = listed.truncated ? listed.cursor : undefined;
  } while (cursor !== undefined);
  const confirmation = await bucket.list({ prefix, limit: 1 });
  if (confirmation.objects.length !== 0) throw new Error("r2_purge_incomplete");
  return checksum;
}

function privacyPurge(environment: Bindings): ConsumerEffect {
  return async (client, event) => {
    if (
      event.tenant_id === null ||
      environment.DELETION_DENY_JOURNAL === undefined ||
      environment.PRIVACY_EXPORTS === undefined ||
      environment.MEDIA_QUARANTINE === undefined
    )
      throw new Error("privacy_purge_unavailable");
    const payload = payloadIds.parse(event.payload);
    if (payload.tombstone_id === undefined)
      throw new Error("invalid_event_payload");
    const selected = await client.query<{
      subject_hash: string;
      effective_at: Date;
      purge_generation: number;
    }>(
      `select subject_hash,effective_at,purge_generation from deletion_tombstones where id=$1 and tenant_id=$2 for update`,
      [payload.tombstone_id, event.tenant_id],
    );
    const tombstone = selected.rows[0];
    if (tombstone === undefined) throw new Error("tombstone_missing");
    const journal = await buildDeletionDenyEntry({
      tombstoneId: payload.tombstone_id,
      tenantId: event.tenant_id,
      subjectHash: tombstone.subject_hash,
      effectiveAt: tombstone.effective_at.toISOString(),
      purgeGeneration: tombstone.purge_generation,
    });
    await environment.DELETION_DENY_JOURNAL.put(journal.key, journal.body, {
      httpMetadata: { contentType: "application/json" },
      customMetadata: { body_checksum: journal.checksum },
    });
    const readBack = await environment.DELETION_DENY_JOURNAL.get(journal.key);
    if (
      readBack === null ||
      !(await verifyDeletionDenyEntry(await readBack.text(), journal.checksum))
    )
      throw new Error("deletion_journal_verification_failed");
    await client.query(
      `insert into deletion_journal_confirmations(tombstone_id,purge_generation,r2_key,body_checksum,confirmed_at) values ($1,$2,$3,$4,now()) on conflict (tombstone_id,purge_generation) do update set r2_key=excluded.r2_key,body_checksum=excluded.body_checksum,confirmed_at=excluded.confirmed_at`,
      [
        payload.tombstone_id,
        tombstone.purge_generation,
        journal.key,
        journal.checksum,
      ],
    );
    const exportChecksum = await deletePrefix(
      environment.PRIVACY_EXPORTS,
      `privacy-exports/v1/${event.tenant_id}/`,
    );
    const quarantineChecksum = await deletePrefix(
      environment.MEDIA_QUARANTINE,
      `tenant-quarantine/v1/${event.tenant_id}/`,
    );
    for (const [objectClass, prefix, checksum] of [
      [
        "privacy_exports",
        `privacy-exports/v1/${event.tenant_id}/`,
        exportChecksum,
      ],
      [
        "tenant_quarantine",
        `tenant-quarantine/v1/${event.tenant_id}/`,
        quarantineChecksum,
      ],
    ] as const)
      await client.query(
        `insert into deletion_object_receipts(tombstone_id,purge_generation,object_class,prefix,listing_checksum,confirmed_empty_at) values ($1,$2,$3,$4,$5,now()) on conflict (tombstone_id,purge_generation,object_class) do update set prefix=excluded.prefix,listing_checksum=excluded.listing_checksum,confirmed_empty_at=excluded.confirmed_empty_at`,
        [
          payload.tombstone_id,
          tombstone.purge_generation,
          objectClass,
          prefix,
          checksum,
        ],
      );
    const receipt = await client.query<{ receipt_id: string }>(
      `select ritual_private.purge_tombstoned_tenant($1,$2) receipt_id`,
      [payload.tombstone_id, tombstone.purge_generation],
    );
    return `purged:${receipt.rows[0]!.receipt_id}`;
  };
}

export function handlerFor(
  message: QueueWorkMessage,
  environment: Bindings,
): ConsumerEffect {
  switch (message.consumer) {
    case "briefing-builder":
      return briefingBuilder();
    case "notification-writer":
      return notificationWriter(environment);
    case "moderation-triage":
      return moderationTriage();
    case "privacy-export":
      return privacyExport(environment);
    case "privacy-purge":
      return privacyPurge(environment);
    case "notification-delivery":
      return notificationDelivery(environment);
    case "media-scan":
      return mediaScan(environment);
    case "media-cleanup":
      return mediaCleanup(environment);
    case "editorial-publisher":
      return editorialPublisher();
    case "recurring-plan-delivery":
      return recurringPlanDelivery();
    case "privacy-export-retention":
      return privacyExportRetention(environment);
  }
}
