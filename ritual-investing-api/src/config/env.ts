import { z } from "zod";

const httpsUrl = z
  .string()
  .url()
  .refine((value) => value.startsWith("https://"), {
    message: "must use https",
  });
const postgresUrl = z
  .string()
  .url()
  .refine(
    (value) => ["postgres:", "postgresql:"].includes(new URL(value).protocol),
    { message: "must use a PostgreSQL connection URL" },
  );
const rateLimitBinding = z.custom<RateLimit>(
  (value) =>
    typeof value === "object" &&
    value !== null &&
    "limit" in value &&
    typeof value.limit === "function",
  { message: "must be a Cloudflare RateLimit binding" },
);
const r2Binding = z.custom<R2Bucket>(
  (value) =>
    typeof value === "object" &&
    value !== null &&
    "get" in value &&
    "put" in value,
  { message: "must be an R2 bucket binding" },
);
const queueBinding = z.custom<Queue>(
  (value) => typeof value === "object" && value !== null && "send" in value,
  { message: "must be a Queue producer binding" },
);
const serviceBinding = z.custom<Fetcher>(
  (value) => typeof value === "object" && value !== null && "fetch" in value,
  { message: "must be a service binding" },
);

export const environmentSchema = z
  .object({
    ENVIRONMENT: z.enum(["development", "test", "staging", "production"]),
    BUILD_REVISION: z.string().min(1).max(128),
    API_ORIGIN: z.string().url(),
    AUTH0_ISSUER: httpsUrl.refine((value) => value.endsWith("/"), {
      message: "must end with a slash",
    }),
    AUTH0_AUDIENCE: httpsUrl,
    AUTH0_JWKS_URL: httpsUrl,
    AUTH0_MEMBER_CLIENT_IDS: z.string().min(1),
    AUTH0_ADMIN_CLIENT_IDS: z.string().min(1),
    CF_ACCESS_ISSUER: httpsUrl,
    CF_ACCESS_AUDIENCE: z.string().min(1).max(255),
    CF_ACCESS_JWKS_URL: httpsUrl,
    CONSUMER_ORIGIN: httpsUrl,
    ADMIN_ORIGIN: httpsUrl,
    ADMIN_HOST: z.string().min(1).max(253),
    ADMIN_UI_HOST: z.string().min(1).max(253).optional(),
    IDENTITY_DATABASE_URL: postgresUrl.optional(),
    BOOTSTRAP_DATABASE_URL: postgresUrl.optional(),
    STAFF_DATABASE_URL: postgresUrl.optional(),
    PUBLIC_DATABASE_URL: postgresUrl.optional(),
    RUNTIME_DATABASE_URL: postgresUrl.optional(),
    SCHEDULER_DATABASE_URL: postgresUrl.optional(),
    PRIVACY_DATABASE_URL: postgresUrl.optional(),
    MEDIA_DATABASE_URL: postgresUrl.optional(),
    AUDIT_DATABASE_URL: postgresUrl.optional(),
    CURSOR_SIGNING_KEY: z.string().min(32).max(512).optional(),
    PUSH_TOKEN_ENCRYPTION_KEY: z.string().min(43).max(128).optional(),
    EXPECTED_RESTORE_EPOCH: z
      .string()
      .regex(/^[A-Za-z0-9._:-]{1,128}$/)
      .optional(),
    KILL_SWITCH_SCHEDULED: z.enum(["off", "on"]).default("off"),
    KILL_SWITCH_QUEUE: z.enum(["off", "on"]).default("off"),
    KILL_SWITCH_NOTIFICATIONS: z.enum(["off", "on"]).default("off"),
    KILL_SWITCH_NOTIFICATION_WRITER: z.enum(["off", "on"]).optional(),
    KILL_SWITCH_NOTIFICATION_DELIVERY: z.enum(["off", "on"]).optional(),
    KILL_SWITCH_EXPORTS: z.enum(["off", "on"]).default("off"),
    KILL_SWITCH_PURGE: z.enum(["off", "on"]).default("off"),
    KILL_SWITCH_MEDIA: z.enum(["off", "on"]).default("off"),
    ASYNC_QUEUE: queueBinding.optional(),
    JOBS_DLQ: queueBinding.optional(),
    MEDIA_QUARANTINE: r2Binding.optional(),
    MEDIA_PUBLIC: r2Binding.optional(),
    PRIVACY_EXPORTS: r2Binding.optional(),
    DELETION_DENY_JOURNAL: r2Binding.optional(),
    MEDIA_SCANNER: serviceBinding.optional(),
    MEDIA_PROCESSOR: serviceBinding.optional(),
    PUSH_PROVIDER: serviceBinding.optional(),
    ADMIN_ASSETS: serviceBinding.optional(),
    RL_HEALTH: rateLimitBinding,
    RL_PUBLIC: rateLimitBinding,
    RL_SEARCH: rateLimitBinding,
    RL_MEMBER_READ: rateLimitBinding,
    RL_MEMBER_WRITE: rateLimitBinding,
    RL_COMMAND: rateLimitBinding,
    RL_SENSITIVE: rateLimitBinding,
    RL_ADMIN_READ: rateLimitBinding,
    RL_ADMIN_WRITE: rateLimitBinding,
    RL_ADMIN_HIGH: rateLimitBinding,
    RL_UPLOAD: rateLimitBinding,
  })
  .passthrough()
  .superRefine((environment, context) => {
    if (!['staging', 'production'].includes(environment.ENVIRONMENT)) return;
    const required = [
      "IDENTITY_DATABASE_URL",
      "BOOTSTRAP_DATABASE_URL",
      "STAFF_DATABASE_URL",
      "PUBLIC_DATABASE_URL",
      "RUNTIME_DATABASE_URL",
      "SCHEDULER_DATABASE_URL",
      "PRIVACY_DATABASE_URL",
      "MEDIA_DATABASE_URL",
      "AUDIT_DATABASE_URL",
      "CURSOR_SIGNING_KEY",
      "ASYNC_QUEUE",
      "JOBS_DLQ",
      "MEDIA_QUARANTINE",
      "MEDIA_PUBLIC",
      "PRIVACY_EXPORTS",
      "DELETION_DENY_JOURNAL",
    ] as const;
    for (const binding of required)
      if (environment[binding] === undefined)
        context.addIssue({
          code: "custom",
          path: [binding],
          message: `${binding} is required in ${environment.ENVIRONMENT}`,
        });
    const enabledDependencies = [
      ...(environment.KILL_SWITCH_MEDIA === "off"
        ? (["MEDIA_SCANNER", "MEDIA_PROCESSOR"] as const)
        : []),
      ...(notificationDeliveryEnabled(environment)
        ? (["PUSH_PROVIDER", "PUSH_TOKEN_ENCRYPTION_KEY"] as const)
        : []),
    ];
    for (const binding of enabledDependencies)
      if (environment[binding] === undefined)
        context.addIssue({
          code: "custom",
          path: [binding],
          message: `${binding} is required while its production feature is enabled`,
        });
    if (
      environment.ASYNC_QUEUE !== undefined &&
      typeof (environment.ASYNC_QUEUE as { sendBatch?: unknown }).sendBatch !==
        "function"
    )
      context.addIssue({
        code: "custom",
        path: ["ASYNC_QUEUE"],
        message: "ASYNC_QUEUE must support sendBatch",
      });
    if (
      environment.ADMIN_UI_HOST !== undefined &&
      environment.ADMIN_ASSETS === undefined
    )
      context.addIssue({
        code: "custom",
        path: ["ADMIN_ASSETS"],
        message: "ADMIN_ASSETS is required when ADMIN_UI_HOST is configured",
      });
  });

export type Bindings = z.infer<typeof environmentSchema>;

export function notificationWriterEnabled(
  environment: Pick<
    Bindings,
    "KILL_SWITCH_NOTIFICATIONS" | "KILL_SWITCH_NOTIFICATION_WRITER"
  >,
): boolean {
  return (
    environment.KILL_SWITCH_NOTIFICATION_WRITER ??
    environment.KILL_SWITCH_NOTIFICATIONS ??
    "off"
  ) === "off";
}

export function notificationDeliveryEnabled(
  environment: Pick<
    Bindings,
    "KILL_SWITCH_NOTIFICATIONS" | "KILL_SWITCH_NOTIFICATION_DELIVERY"
  >,
): boolean {
  return (
    environment.KILL_SWITCH_NOTIFICATION_DELIVERY ??
    environment.KILL_SWITCH_NOTIFICATIONS ??
    "off"
  ) === "off";
}

export function validateBindings(input: unknown): Bindings {
  return environmentSchema.parse(input);
}
