import { z } from "zod";

const httpsUrl = z.string().url().refine((value) => value.startsWith("https://"), {
  message: "must use https",
});
const postgresUrl = z.string().url().refine(
  (value) => ["postgres:", "postgresql:"].includes(new URL(value).protocol),
  { message: "must use a PostgreSQL connection URL" },
);
const rateLimitBinding = z.custom<RateLimit>(
  (value) => typeof value === "object"
    && value !== null
    && "limit" in value
    && typeof value.limit === "function",
  { message: "must be a Cloudflare RateLimit binding" },
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
    AUTH0_ADMIN_CLIENT_IDS: z.string().min(1),
    CF_ACCESS_ISSUER: httpsUrl,
    CF_ACCESS_AUDIENCE: z.string().min(1).max(255),
    CF_ACCESS_JWKS_URL: httpsUrl,
    CONSUMER_ORIGIN: httpsUrl,
    ADMIN_ORIGIN: httpsUrl,
    ADMIN_HOST: z.string().min(1).max(253),
    IDENTITY_DATABASE_URL: postgresUrl.optional(),
    BOOTSTRAP_DATABASE_URL: postgresUrl.optional(),
    STAFF_DATABASE_URL: postgresUrl.optional(),
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
  .passthrough();

export type Bindings = z.infer<typeof environmentSchema>;

export function validateBindings(input: unknown): Bindings {
  return environmentSchema.parse(input);
}
