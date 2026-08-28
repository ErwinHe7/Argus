import { z } from "zod";

const verifiedRequestClaimsSchema = z
  .object({
    userId: z.string().uuid(),
    sessionId: z.string().uuid(),
    aal: z.enum(["aal1", "aal2"]),
  })
  .strict();

/**
 * Authorization claims accepted by the portable database boundary. These
 * values must come from the already-verified Supabase access token; request
 * bodies and route parameters are deliberately not part of this type.
 */
export type VerifiedRequestClaims = Readonly<
  z.infer<typeof verifiedRequestClaimsSchema>
>;

export function createVerifiedRequestClaims(
  input: z.input<typeof verifiedRequestClaimsSchema>,
): VerifiedRequestClaims {
  return Object.freeze(verifiedRequestClaimsSchema.parse(input));
}

const resolverContextSchema = z
  .object({
    accountId: z.string().uuid(),
    tenantId: z.string().uuid(),
    principal: z.string().min(1).max(255),
    accountStatus: z.enum(["active"]).default("active"),
    tenantStatus: z.enum(["active"]).default("active"),
    revocationEpoch: z.number().int().nonnegative(),
  })
  .strict();

export type RequestDatabaseContext = Readonly<
  z.infer<typeof resolverContextSchema>
>;

export function createRequestDatabaseContext(
  input: z.input<typeof resolverContextSchema>,
): RequestDatabaseContext {
  return Object.freeze(resolverContextSchema.parse(input));
}
/**
 * Apply the application-level half of the tenant/IDOR boundary. Callers expose
 * the same non-enumerating error for a missing row and a row owned by another
 * tenant; PostgreSQL RLS independently enforces the same boundary.
 */
export function assertTenantResource(
  context: RequestDatabaseContext,
  resourceTenantId: string | null | undefined,
): void {
  if (resourceTenantId !== context.tenantId) {
    throw new Error("resource_not_found");
  }
}
