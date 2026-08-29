import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { AccountRepository } from "./ports.ts";
import {
  astrologyBodySchema,
  astrologyProfileResponseSchema,
  consentBodySchema,
  consentReceiptResponseSchema,
  deleteAstrologyProfileResponseSchema,
  investorBodySchema,
  investorProfileResponseSchema,
  memberAccountResponseSchema,
  preferencesPatchSchema,
  updatePreferencesResponseSchema,
} from "./schemas.ts";
import {
  dataResponse,
  expectedVersion,
  parseBody,
  rejectBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type AccountRouteRepository = AccountRepository;

type AccountRouteDependencies = Readonly<{
  register: RetainedRouteRegistrar;
  repository: (
    context: Context<RetainedAppEnvironment>,
  ) => AccountRouteRepository;
}>;

export function registerAccountReadRoute(
  input: AccountRouteDependencies,
): void {
  const account = retainedRoute("get", "/v1/account", "getAccount", "Account", {
    response: memberAccountResponseSchema,
  });
  input.register(
    account,
    async (context) =>
      dataResponse(context, await input.repository(context).get()),
  );
}

export function registerAccountMutationRoutes(
  input: AccountRouteDependencies,
): void {
  const updatePreferences = retainedRoute(
    "patch",
    "/v1/preferences",
    "updatePreferences",
    "Account",
    {
      body: preferencesPatchSchema,
      headers: z.object({ "if-match": z.string() }),
      response: updatePreferencesResponseSchema,
    },
  );
  input.register(updatePreferences, async (context) => {
    const patch = await parseBody(context, preferencesPatchSchema);
    return dataResponse(
      context,
      await input.repository(context).updatePreferences(
        {
          ...(patch.themeMode === undefined
            ? {}
            : { themeMode: patch.themeMode }),
          ...(patch.ritualMode === undefined
            ? {}
            : { ritualMode: patch.ritualMode }),
          ...(patch.timezone === undefined ? {} : { timezone: patch.timezone }),
          ...(patch.locale === undefined ? {} : { locale: patch.locale }),
        },
        expectedVersion(context),
      ),
    );
  });

  const updateInvestor = retainedRoute(
    "put",
    "/v1/investor-profile",
    "updateInvestorProfile",
    "Account",
    {
      body: investorBodySchema,
      headers: z.object({ "if-match": z.string().optional() }),
      response: investorProfileResponseSchema,
    },
  );
  input.register(updateInvestor, async (context) => {
    const body = await parseBody(context, investorBodySchema);
    const rawVersion = context.req.header("if-match");
    return dataResponse(
      context,
      await input.repository(context).updateInvestor(
        body,
        rawVersion === undefined ? undefined : expectedVersion(context),
      ),
    );
  });

  const updateAstrology = retainedRoute(
    "put",
    "/v1/astrology-profile",
    "updateAstrologyProfile",
    "Account",
    {
      body: astrologyBodySchema,
      headers: z.object({ "if-match": z.string().optional() }),
      response: astrologyProfileResponseSchema,
    },
  );
  input.register(updateAstrology, async (context) => {
    const body = await parseBody(context, astrologyBodySchema);
    const rawVersion = context.req.header("if-match");
    return dataResponse(
      context,
      await input.repository(context).updateAstrology(
        body.birthDate,
        rawVersion === undefined ? undefined : expectedVersion(context),
      ),
    );
  });

  const deleteAstrology = retainedRoute(
    "delete",
    "/v1/astrology-profile",
    "deleteAstrologyProfile",
    "Account",
    {
      headers: z.object({ "if-match": z.string() }),
      response: deleteAstrologyProfileResponseSchema,
    },
  );
  input.register(deleteAstrology, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await input.repository(context).deleteAstrology(expectedVersion(context)),
    );
  });

  const consent = retainedRoute(
    "post",
    "/v1/consents",
    "recordConsent",
    "Account",
    {
      body: consentBodySchema,
      response: consentReceiptResponseSchema,
    },
  );
  input.register(consent, async (context) =>
    dataResponse(
      context,
      await input.repository(context).recordConsent(
        await parseBody(context, consentBodySchema),
      ),
    ));
}
