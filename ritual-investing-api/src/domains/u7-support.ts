import type { Context } from "hono";

import type { AppEnvironment } from "../app.ts";
import type { MemberContext } from "./accounts/repository.ts";

export function currentMember(
  context: Context<AppEnvironment>,
): MemberContext | undefined {
  const account = context.get("accountTenant");
  const principal = context.get("authPrincipal");
  return account === undefined || principal === undefined
    ? undefined
    : { ...account, subject: principal.subject };
}

export const pageMeta = (requestId: string) => ({ request_id: requestId });
