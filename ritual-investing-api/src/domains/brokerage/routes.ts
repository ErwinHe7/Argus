import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { VerifiedRequestClaims } from "../../db/request-claims.ts";
import type { BrokerageOrderService } from "../brokerage-orders/service.ts";
import type { BrokerageProjectionService } from "../brokerage-projections/service.ts";
import type { BrokerageProjectionResource } from "../brokerage-projections/types.ts";
import {
  dataResponse,
  HttpBoundaryError,
  parseBody,
  rejectBody,
  retainedRoute as defineRetainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  idempotencyKeySchema,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";
import {
  brokerageAccountsResponseSchema,
  brokerageBalancesResponseSchema,
  brokerageCapabilitiesResponseSchema,
  brokerageOrderCommandResponseSchema,
  brokerageOrderDetailResponseSchema,
  brokerageOrderPreviewResponseSchema,
  brokerageOrdersResponseSchema,
  brokeragePositionsResponseSchema,
  brokerageRestrictionsResponseSchema,
  completionBodySchema,
  confirmCancelOrderSchema,
  confirmModifyOrderSchema,
  confirmPlaceOrderSchema,
  connectionStartBodySchema,
  disconnectBodySchema,
  memberStepUpReceiptResponseSchema,
  modifyOrderIntentSchema,
  placeOrderIntentSchema,
  selectAccountBodySchema,
  stepUpBodySchema,
  webullAccountSelectionResponseSchema,
  webullAuthorizationSessionResponseSchema,
  webullCompletionResponseSchema,
  webullConnectionResponseSchema,
  webullDisconnectResponseSchema,
} from "./routes-schemas.ts";

const retainedRoute = (
  ...args: Parameters<typeof defineRetainedRoute>
): ReturnType<typeof defineRetainedRoute> => {
  const [method, path, operationId, tag, options = {}] = args;
  return defineRetainedRoute(method, path, operationId, tag, {
    ...options,
    transaction: "none",
  });
};

/** Public capability consumed by retained brokerage connection routes. */
export interface BrokerageConnectionRouteService {
  issueStepUp(action: "webull_disconnect" | "argus_delete"): Promise<unknown>;
  start(returnTarget: "webull_https" | "webull_native"): Promise<unknown>;
  reconnect(returnTarget: "webull_https" | "webull_native"): Promise<unknown>;
  status(): Promise<unknown>;
  selectAccount(accountId: string): Promise<unknown>;
  redeemCompletion(completion: string): Promise<unknown>;
  disconnect(stepUpReceipt: string): Promise<unknown>;
}

type BrokerageRouteDependencies = Readonly<{
  register: RetainedRouteRegistrar;
  createConnections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageConnectionRouteService;
  createProjections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageProjectionService;
  createOrders?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageOrderService;
}>;

function connections(
  context: Context<RetainedAppEnvironment>,
  input: BrokerageRouteDependencies,
): BrokerageConnectionRouteService {
  if (input.createConnections === undefined) {
    throw new HttpBoundaryError(
      503,
      "webull_contract_unavailable",
      "Webull connection is temporarily unavailable.",
      true,
    );
  }
  return input.createConnections(context.get("claims"));
}

function projections(
  context: Context<RetainedAppEnvironment>,
  input: BrokerageRouteDependencies,
): BrokerageProjectionService {
  if (input.createProjections === undefined) {
    throw new HttpBoundaryError(
      503,
      "brokerage_reads_unavailable",
      "Brokerage data is temporarily unavailable.",
      true,
    );
  }
  return input.createProjections(context.get("claims"));
}

function orders(
  context: Context<RetainedAppEnvironment>,
  input: BrokerageRouteDependencies,
): BrokerageOrderService {
  if (input.createOrders === undefined) {
    throw new HttpBoundaryError(
      503,
      "brokerage_orders_unavailable",
      "Brokerage orders are temporarily unavailable.",
      true,
    );
  }
  return input.createOrders(context.get("claims"));
}

export function registerBrokerageRoutes(
  input: BrokerageRouteDependencies,
): void {
  const issueStepUp = retainedRoute(
    "post",
    "/v1/member/step-up",
    "issueMemberStepUp",
    "Member Security",
    {
      body: stepUpBodySchema,
      response: memberStepUpReceiptResponseSchema,
    },
  );
  input.register(issueStepUp, async (context) => {
    const body = await parseBody(context, stepUpBodySchema);
    const origin = context.req.header("origin");
    if (
      origin !== undefined &&
      context.env.consumerOrigins.includes(origin) &&
      body.action !== "argus_delete"
    ) {
      throw new HttpBoundaryError(
        503,
        "web_capability_unavailable",
        "This capability is not available on the public beta website.",
      );
    }
    const authenticatedAt = context.get("principal").authenticatedAt;
    const currentSeconds = Math.floor(Date.now() / 1_000);
    if (
      authenticatedAt === undefined ||
      authenticatedAt > currentSeconds + 30 ||
      currentSeconds - authenticatedAt > 300
    ) {
      throw new HttpBoundaryError(
        403,
        "recent_auth_required",
        "Recent authentication is required.",
      );
    }
    return dataResponse(
      context,
      await connections(context, input).issueStepUp(body.action),
    );
  });

  const startConnection = retainedRoute(
    "post",
    "/v1/brokerage/connections/start",
    "startWebullConnection",
    "Brokerage Connections",
    {
      body: connectionStartBodySchema,
      response: webullAuthorizationSessionResponseSchema,
    },
  );
  input.register(startConnection, async (context) => {
    const body = await parseBody(context, connectionStartBodySchema);
    return dataResponse(
      context,
      await connections(context, input).start(body.return_target),
    );
  });

  const reconnect = retainedRoute(
    "post",
    "/v1/brokerage/connections/reconnect",
    "reconnectWebullConnection",
    "Brokerage Connections",
    {
      body: connectionStartBodySchema,
      response: webullAuthorizationSessionResponseSchema,
    },
  );
  input.register(reconnect, async (context) => {
    const body = await parseBody(context, connectionStartBodySchema);
    return dataResponse(
      context,
      await connections(context, input).reconnect(body.return_target),
    );
  });

  const getConnection = retainedRoute(
    "get",
    "/v1/brokerage/connection",
    "getWebullConnection",
    "Brokerage Connections",
    { response: webullConnectionResponseSchema },
  );
  input.register(getConnection, async (context) =>
    dataResponse(context, await connections(context, input).status()));

  const selectBrokerageAccount = retainedRoute(
    "patch",
    "/v1/brokerage/accounts/selection",
    "selectWebullAccount",
    "Brokerage Connections",
    {
      body: selectAccountBodySchema,
      response: webullAccountSelectionResponseSchema,
    },
  );
  input.register(selectBrokerageAccount, async (context) => {
    const body = await parseBody(context, selectAccountBodySchema);
    return dataResponse(
      context,
      await connections(context, input).selectAccount(body.account_id),
    );
  });

  const redeemCompletion = retainedRoute(
    "post",
    "/v1/brokerage/connections/completions/redeem",
    "redeemWebullCompletion",
    "Brokerage Connections",
    {
      body: completionBodySchema,
      response: webullCompletionResponseSchema,
    },
  );
  input.register(redeemCompletion, async (context) => {
    const body = await parseBody(context, completionBodySchema);
    return dataResponse(
      context,
      await connections(context, input).redeemCompletion(body.completion),
    );
  });

  const disconnect = retainedRoute(
    "post",
    "/v1/brokerage/connections/disconnect",
    "disconnectWebullConnection",
    "Brokerage Connections",
    {
      body: disconnectBodySchema,
      response: webullDisconnectResponseSchema,
    },
  );
  input.register(disconnect, async (context) => {
    const body = await parseBody(context, disconnectBodySchema);
    return dataResponse(
      context,
      await connections(context, input).disconnect(body.step_up_receipt),
    );
  });

  const listBrokerageAccounts = retainedRoute(
    "get",
    "/v1/brokerage/accounts",
    "listWebullAccounts",
    "Brokerage Reads",
    {
      description: "Owner-scoped Webull accounts and normalized capabilities.",
      response: brokerageAccountsResponseSchema,
    },
  );
  input.register(listBrokerageAccounts, async (context) =>
    dataResponse(context, await projections(context, input).listAccounts()));

  const brokerageReadPath = z.object({ account_id: uuidSchema });
  const brokerageReadQuery = z.object({
    refresh: z.enum(["true", "false"]).optional(),
  });
  for (
    const [path, operationId, resource, response] of [
      [
        "/v1/brokerage/accounts/{account_id}/capabilities",
        "getWebullAccountCapabilities",
        "account",
        brokerageCapabilitiesResponseSchema,
      ],
      [
        "/v1/brokerage/accounts/{account_id}/balances",
        "getWebullBalances",
        "balance",
        brokerageBalancesResponseSchema,
      ],
      [
        "/v1/brokerage/accounts/{account_id}/positions",
        "getWebullPositions",
        "positions",
        brokeragePositionsResponseSchema,
      ],
      [
        "/v1/brokerage/accounts/{account_id}/restrictions",
        "getWebullRestrictions",
        "restrictions",
        brokerageRestrictionsResponseSchema,
      ],
    ] as const satisfies readonly (readonly [
      string,
      string,
      BrokerageProjectionResource,
      z.ZodType,
    ])[]
  ) {
    const definition = retainedRoute(
      "get",
      path,
      operationId,
      "Brokerage Reads",
      {
        pathParams: brokerageReadPath,
        query: brokerageReadQuery,
        description:
          "Immutable provider-authoritative projection with independent freshness timestamps.",
        response,
      },
    );
    input.register(definition, async (context) =>
      dataResponse(
        context,
        await projections(context, input).read(
          uuidSchema.parse(context.req.param("account_id")),
          resource,
          context.req.query("refresh") === "true",
        ),
      ));
  }

  const accountPath = z.object({ account_id: uuidSchema });
  const orderReadQuery = z.object({
    refresh: z.enum(["true", "false"]).optional(),
  });
  const orderPath = z.object({
    account_id: uuidSchema,
    order_id: uuidSchema,
  });
  const listOrders = retainedRoute(
    "get",
    "/v1/brokerage/accounts/{account_id}/orders",
    "listWebullOrders",
    "Brokerage Orders",
    {
      pathParams: accountPath,
      query: orderReadQuery,
      description: "Provider-authoritative order history with explicit freshness.",
      response: brokerageOrdersResponseSchema,
    },
  );
  input.register(listOrders, async (context) =>
    dataResponse(
      context,
      await orders(context, input).listOrders(
        uuidSchema.parse(context.req.param("account_id")),
        context.req.query("refresh") === "true",
      ),
    ));

  const getOrder = retainedRoute(
    "get",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}",
    "getWebullOrder",
    "Brokerage Orders",
    {
      pathParams: orderPath,
      description:
        "Latest positive order detail evidence; provider identifiers stay private.",
      response: brokerageOrderDetailResponseSchema,
    },
  );
  input.register(getOrder, async (context) =>
    dataResponse(
      context,
      await orders(context, input).order(
        uuidSchema.parse(context.req.param("account_id")),
        uuidSchema.parse(context.req.param("order_id")),
      ),
    ));

  const previewPlace = retainedRoute(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/previews",
    "previewWebullOrder",
    "Brokerage Orders",
    {
      pathParams: accountPath,
      body: placeOrderIntentSchema,
      description:
        "Short-lived capability- and restriction-bound manual order review.",
      response: brokerageOrderPreviewResponseSchema,
    },
  );
  input.register(previewPlace, async (context) =>
    dataResponse(
      context,
      await orders(context, input).previewPlace(
        uuidSchema.parse(context.req.param("account_id")),
        await parseBody(context, placeOrderIntentSchema),
      ),
    ));

  const previewModify = retainedRoute(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}/modify-preview",
    "previewWebullOrderModification",
    "Brokerage Orders",
    {
      pathParams: orderPath,
      body: modifyOrderIntentSchema,
      description: "Review a modification only after proving target-order ownership.",
      response: brokerageOrderPreviewResponseSchema,
    },
  );
  input.register(previewModify, async (context) =>
    dataResponse(
      context,
      await orders(context, input).previewModify(
        uuidSchema.parse(context.req.param("account_id")),
        uuidSchema.parse(context.req.param("order_id")),
        await parseBody(context, modifyOrderIntentSchema),
      ),
    ));

  const previewCancel = retainedRoute(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel-preview",
    "previewWebullOrderCancellation",
    "Brokerage Orders",
    {
      pathParams: orderPath,
      description: "Review cancellation only after proving target-order ownership.",
      response: brokerageOrderPreviewResponseSchema,
    },
  );
  input.register(previewCancel, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await orders(context, input).previewCancel(
        uuidSchema.parse(context.req.param("account_id")),
        uuidSchema.parse(context.req.param("order_id")),
      ),
    );
  });

  const mutationHeaders = z.object({ "idempotency-key": idempotencyKeySchema });
  const placeOrder = retainedRoute(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders",
    "placeWebullOrder",
    "Brokerage Orders",
    {
      pathParams: accountPath,
      headers: mutationHeaders,
      body: confirmPlaceOrderSchema,
      description:
        "Persist once before one provider submission; ambiguous results are never blindly retried.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  input.register(placeOrder, async (context) => {
    const body = await parseBody(context, confirmPlaceOrderSchema);
    return dataResponse(
      context,
      await orders(context, input).confirmPlace({
        accountId: uuidSchema.parse(context.req.param("account_id")),
        previewId: body.preview_id,
        idempotencyKey: idempotencyKeySchema.parse(
          context.req.header("idempotency-key"),
        ),
        intent: body.intent,
      }),
    );
  });

  const modifyOrder = retainedRoute(
    "patch",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}",
    "modifyWebullOrder",
    "Brokerage Orders",
    {
      pathParams: orderPath,
      headers: mutationHeaders,
      body: confirmModifyOrderSchema,
      description:
        "Create a distinct durable modification command against an owned order.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  input.register(modifyOrder, async (context) => {
    const body = await parseBody(context, confirmModifyOrderSchema);
    return dataResponse(
      context,
      await orders(context, input).confirmModify({
        accountId: uuidSchema.parse(context.req.param("account_id")),
        orderId: uuidSchema.parse(context.req.param("order_id")),
        previewId: body.preview_id,
        idempotencyKey: idempotencyKeySchema.parse(
          context.req.header("idempotency-key"),
        ),
        intent: body.intent,
      }),
    );
  });

  const cancelOrder = retainedRoute(
    "post",
    "/v1/brokerage/accounts/{account_id}/orders/{order_id}/cancel",
    "cancelWebullOrder",
    "Brokerage Orders",
    {
      pathParams: orderPath,
      headers: mutationHeaders,
      body: confirmCancelOrderSchema,
      description:
        "Create a distinct durable cancellation command against an owned order.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  input.register(cancelOrder, async (context) => {
    const body = await parseBody(context, confirmCancelOrderSchema);
    return dataResponse(
      context,
      await orders(context, input).confirmCancel({
        accountId: uuidSchema.parse(context.req.param("account_id")),
        orderId: uuidSchema.parse(context.req.param("order_id")),
        previewId: body.preview_id,
        idempotencyKey: idempotencyKeySchema.parse(
          context.req.header("idempotency-key"),
        ),
      }),
    );
  });

  const commandPath = z.object({ command_id: uuidSchema });
  const getCommand = retainedRoute(
    "get",
    "/v1/brokerage/order-commands/{command_id}",
    "getWebullOrderCommand",
    "Brokerage Orders",
    {
      pathParams: commandPath,
      description: "Owner-scoped redacted command and reconciliation state.",
      response: brokerageOrderCommandResponseSchema,
    },
  );
  input.register(getCommand, async (context) =>
    dataResponse(
      context,
      await orders(context, input).command(
        uuidSchema.parse(context.req.param("command_id")),
      ),
    ));
}
