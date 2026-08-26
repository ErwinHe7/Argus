import { Hono } from "hono";

import {
  type AnalyticsBinding,
  type RetentionCheckpointBinding,
  type RuntimeSiteEnv,
  type SiteEnv,
} from "./config.ts";
import {
  runScheduledRetention,
  type PurgeCapability,
  type RetentionCheckpoint,
  type RetentionTelemetryPoint,
} from "./retention/scheduled.ts";
import { handleWaitlistRequest, type WaitlistRouteDependencies } from "./waitlist/route.ts";

export type { RuntimeSiteEnv, SiteEnv } from "./config.ts";

type WorkerDependencies = {
  purgeFactory?: (environment: RuntimeSiteEnv) => PurgeCapability;
  checkpointFactory?: (environment: RuntimeSiteEnv) => RetentionCheckpoint;
  sleep?: (milliseconds: number) => Promise<void>;
  waitlist?: WaitlistRouteDependencies;
};

export type SiteWorker = {
  fetch(request: Request, environment: RuntimeSiteEnv, executionContext: ExecutionContext): Promise<Response>;
  scheduled(
    controller: Pick<ScheduledController, "scheduledTime">,
    environment: RuntimeSiteEnv,
    executionContext: ExecutionContext,
  ): void;
};

const LAST_SUCCESS_KEY = "retention:last-success-scheduled-at:v1";

function createApiApp(waitlistDependencies: WaitlistRouteDependencies): Hono<{ Bindings: SiteEnv }> {
  const app = new Hono<{ Bindings: SiteEnv }>();

  app.all("/api/waitlist", (context) =>
    handleWaitlistRequest(context.req.raw, context.env, waitlistDependencies),
  );
  app.all("/api/*", (context) =>
    context.json({ code: "api_route_not_found" }, 404, {
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    }),
  );

  return app;
}

function unavailablePurgeCapability(): PurgeCapability {
  return {
    async purgeExpired(): Promise<void> {
      throw new Error("Waitlist retention capability is not configured.");
    },
  };
}

function checkpoint(binding: RetentionCheckpointBinding | undefined): RetentionCheckpoint {
  if (binding === undefined) {
    return {
      async readLastSuccess(): Promise<null> {
        return null;
      },
      async recordSuccess(): Promise<void> {
        throw new Error("Retention checkpoint is not configured.");
      },
    };
  }

  return {
    async readLastSuccess(): Promise<number | null> {
      const stored = await binding.get(LAST_SUCCESS_KEY);
      if (stored === null) return null;
      const parsed = Number(stored);
      return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : null;
    },
    async recordSuccess(scheduledAt: number): Promise<void> {
      const stored = await binding.get(LAST_SUCCESS_KEY);
      const current = stored === null ? null : Number(stored);
      if (Number.isSafeInteger(current) && (current as number) >= scheduledAt) return;
      await binding.put(LAST_SUCCESS_KEY, String(scheduledAt));
    },
  };
}

function emitRetentionTelemetry(
  binding: AnalyticsBinding | undefined,
  environment: RuntimeSiteEnv["ENVIRONMENT"],
  point: RetentionTelemetryPoint,
): void {
  binding?.writeDataPoint({
    indexes: [point.event],
    blobs: [environment, point.overdue ? "overdue" : "within_window"],
    doubles: [point.attempts, point.overdue ? 1 : 0],
  });
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function createWorker(dependencies: WorkerDependencies = {}): SiteWorker {
  const api = createApiApp(dependencies.waitlist ?? {});
  const purgeFactory = dependencies.purgeFactory ?? (() => unavailablePurgeCapability());
  const checkpointFactory = dependencies.checkpointFactory ??
    ((environment) => checkpoint(environment.RETENTION_CHECKPOINT));
  const sleep = dependencies.sleep ?? delay;

  return {
    async fetch(request, environment, executionContext): Promise<Response> {
      const url = new URL(request.url);
      if (
        environment.ENVIRONMENT === "production" &&
        url.hostname === "www.just-build-this.app"
      ) {
        return new Response(null, {
          status: 308,
          headers: {
            location: `https://just-build-this.app${url.pathname}${url.search}`,
            "cache-control": "public, max-age=3600",
            "x-content-type-options": "nosniff",
          },
        });
      }
      const pathname = url.pathname;
      if (pathname.startsWith("/api/")) {
        return api.fetch(request, environment, executionContext);
      }
      return environment.ASSETS.fetch(request);
    },
    scheduled(controller, environment, executionContext): void {
      const task = runScheduledRetention({
        scheduledAt: controller.scheduledTime,
        purge: purgeFactory(environment),
        checkpoint: checkpointFactory(environment),
        emit: (point) => emitRetentionTelemetry(environment.WAITLIST_TELEMETRY, environment.ENVIRONMENT, point),
        sleep,
      });
      executionContext.waitUntil(task);
    },
  };
}

export default createWorker() satisfies ExportedHandler<SiteEnv>;
