import { z } from "zod";

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
