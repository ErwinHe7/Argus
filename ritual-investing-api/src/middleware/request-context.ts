import type { MiddlewareHandler } from "hono";

export type RequestContextVariables = {
  requestId: string;
};

const trustedRequestId = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const requestContext: MiddlewareHandler<{
  Variables: RequestContextVariables;
}> = async (context, next) => {
  const incoming = context.req.header("x-request-id");
  const requestId = incoming && trustedRequestId.test(incoming) ? incoming : crypto.randomUUID();
  context.set("requestId", requestId);
  context.header("x-request-id", requestId);
  await next();
};

export function requestIdFrom(context: {
  get(key: "requestId"): string | undefined;
}): string {
  return context.get("requestId") ?? crypto.randomUUID();
}
