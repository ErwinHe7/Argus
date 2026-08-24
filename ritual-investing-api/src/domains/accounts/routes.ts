import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  errorResponseSchema,
  etagSchema,
  objectResponse,
} from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  memberAccess,
  memberSecurity,
  type MemberRouteDependencies,
  versionFrom,
} from "./access.ts";
import { InvalidTransitionError, VersionConflictError } from "./repository.ts";
import {
  accountViewSchema,
  astrologyProfileSchema,
  astrologyPutSchema,
  consentReceiptSchema,
  consentRequestSchema,
  investorProfileSchema,
  investorPutSchema,
  onboardingPatchSchema,
  onboardingSchema,
  preferencesPatchSchema,
  preferencesSchema,
  profilePatchSchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Invalid access token.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Inactive account or permission denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Optional member state not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "Version conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  413: {
    description: "Body too large.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  415: {
    description: "Unsupported media.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid input.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Storage unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;

const readSecurity = [{ Auth0OAuth: ["read:self"] }];
const writeSecurity = [{ Auth0OAuth: ["write:self"] }];
const ifMatch = z.object({ "if-match": etagSchema });
const optionalIfMatch = z.object({ "if-match": etagSchema.optional() });

const meRoute = createRoute({
  method: "get",
  path: "/v1/me",
  operationId: "getMe",
  tags: ["Account"],
  security: readSecurity,
  responses: {
    200: {
      description: "Account and profile.",
      content: {
        "application/json": {
          schema: objectResponse(accountViewSchema).openapi(
            "MemberAccountResponse",
          ),
        },
      },
    },
    ...errors,
  },
});
const patchProfileRoute = createRoute({
  method: "patch",
  path: "/v1/me/profile",
  operationId: "patchProfile",
  tags: ["Account"],
  security: writeSecurity,
  request: {
    headers: ifMatch,
    body: {
      required: true,
      content: { "application/json": { schema: profilePatchSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated profile.",
      content: {
        "application/json": {
          schema: objectResponse(accountViewSchema).openapi(
            "MemberProfileResponse",
          ),
        },
      },
    },
    ...errors,
  },
});
const getPreferencesRoute = createRoute({
  method: "get",
  path: "/v1/me/preferences",
  operationId: "getPreferences",
  tags: ["Account"],
  security: readSecurity,
  responses: {
    200: {
      description: "Preferences.",
      content: {
        "application/json": {
          schema: objectResponse(preferencesSchema).openapi(
            "MemberPreferencesResponse",
          ),
        },
      },
    },
    ...errors,
  },
});
const patchPreferencesRoute = createRoute({
  method: "patch",
  path: "/v1/me/preferences",
  operationId: "patchPreferences",
  tags: ["Account"],
  security: writeSecurity,
  request: {
    headers: ifMatch,
    body: {
      required: true,
      content: { "application/json": { schema: preferencesPatchSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated preferences.",
      content: {
        "application/json": { schema: objectResponse(preferencesSchema) },
      },
    },
    ...errors,
  },
});
const getOnboardingRoute = createRoute({
  method: "get",
  path: "/v1/me/onboarding",
  operationId: "getOnboarding",
  tags: ["Account"],
  security: readSecurity,
  responses: {
    200: {
      description: "Onboarding state.",
      content: {
        "application/json": {
          schema:
            objectResponse(onboardingSchema).openapi("OnboardingResponse"),
        },
      },
    },
    ...errors,
  },
});
const patchOnboardingRoute = createRoute({
  method: "patch",
  path: "/v1/me/onboarding",
  operationId: "patchOnboarding",
  tags: ["Account"],
  security: writeSecurity,
  request: {
    headers: ifMatch,
    body: {
      required: true,
      content: { "application/json": { schema: onboardingPatchSchema } },
    },
  },
  responses: {
    200: {
      description: "Advanced onboarding.",
      content: {
        "application/json": { schema: objectResponse(onboardingSchema) },
      },
    },
    ...errors,
  },
});
const getAstrologyRoute = createRoute({
  method: "get",
  path: "/v1/me/astrology-profile",
  operationId: "getAstrologyProfile",
  tags: ["Account"],
  security: readSecurity,
  responses: {
    200: {
      description: "Astrology profile.",
      content: {
        "application/json": {
          schema: objectResponse(astrologyProfileSchema).openapi(
            "AstrologyProfileResponse",
          ),
        },
      },
    },
    ...errors,
  },
});
const putAstrologyRoute = createRoute({
  method: "put",
  path: "/v1/me/astrology-profile",
  operationId: "putAstrologyProfile",
  tags: ["Account"],
  security: writeSecurity,
  request: {
    headers: optionalIfMatch,
    body: {
      required: true,
      content: { "application/json": { schema: astrologyPutSchema } },
    },
  },
  responses: {
    200: {
      description: "Astrology profile.",
      content: {
        "application/json": { schema: objectResponse(astrologyProfileSchema) },
      },
    },
    ...errors,
  },
});
const deleteAstrologyRoute = createRoute({
  method: "delete",
  path: "/v1/me/astrology-profile",
  operationId: "deleteAstrologyProfile",
  tags: ["Account"],
  security: writeSecurity,
  request: { headers: optionalIfMatch },
  responses: { 204: { description: "Deleted idempotently." }, ...errors },
});
const getInvestorRoute = createRoute({
  method: "get",
  path: "/v1/me/investor-profile",
  operationId: "getInvestorProfile",
  tags: ["Account"],
  security: readSecurity,
  responses: {
    200: {
      description: "Demo investor profile.",
      content: {
        "application/json": {
          schema: objectResponse(investorProfileSchema).openapi(
            "InvestorProfileResponse",
          ),
        },
      },
    },
    ...errors,
  },
});
const putInvestorRoute = createRoute({
  method: "put",
  path: "/v1/me/investor-profile",
  operationId: "putInvestorProfile",
  tags: ["Account"],
  security: writeSecurity,
  request: {
    headers: optionalIfMatch,
    body: {
      required: true,
      content: { "application/json": { schema: investorPutSchema } },
    },
  },
  responses: {
    200: {
      description: "Demo investor profile.",
      content: {
        "application/json": { schema: objectResponse(investorProfileSchema) },
      },
    },
    ...errors,
  },
});
const postConsentRoute = createRoute({
  method: "post",
  path: "/v1/me/consents",
  operationId: "createConsent",
  tags: ["Account"],
  security: writeSecurity,
  request: {
    body: {
      required: true,
      content: { "application/json": { schema: consentRequestSchema } },
    },
  },
  responses: {
    200: {
      description: "Idempotent consent receipt.",
      content: {
        "application/json": {
          schema: objectResponse(consentReceiptSchema).openapi(
            "ConsentReceiptResponse",
          ),
        },
      },
    },
    ...errors,
  },
});

export function registerAccountRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: MemberRouteDependencies = {},
): void {
  const access = (context: any) => memberAccess(context, dependencies);
  const success = (context: any, data: unknown) => {
    const version = responseVersion(data);
    if (version !== undefined) context.header("ETag", `"v${version}"`);
    return context.json(
      { data, meta: { request_id: requestIdFrom(context) } },
      200,
    );
  };
  const secure = (
    route: { getRoutingPath(): string; method: string },
    write: boolean,
  ) => {
    for (const middleware of memberSecurity(
      dependencies,
      write,
      route.method,
    )) {
      app.use(route.getRoutingPath(), middleware);
    }
  };
  const run = async (
    context: any,
    action: (
      member: NonNullable<ReturnType<typeof access>>,
    ) => Promise<unknown>,
  ) => {
    const member = access(context);
    if (member === undefined) return unavailable(context);
    try {
      return success(context, await action(member));
    } catch (error) {
      if (error instanceof VersionConflictError) {
        return errorResponse(
          context,
          409,
          "version_conflict",
          "This resource changed. Refresh before retrying.",
        );
      }
      if (error instanceof InvalidTransitionError) {
        return errorResponse(
          context,
          422,
          "invalid_transition",
          "The requested transition is not allowed.",
        );
      }
      return unavailable(context);
    }
  };
  const optional = async (
    context: any,
    action: (
      member: NonNullable<ReturnType<typeof access>>,
    ) => Promise<unknown | null>,
  ) => {
    const member = access(context);
    if (member === undefined) return unavailable(context);
    try {
      const value = await action(member);
      return value === null
        ? errorResponse(
            context,
            404,
            "not_found",
            "The requested resource was not found.",
          )
        : success(context, value);
    } catch {
      return unavailable(context);
    }
  };

  secure(meRoute, false);
  app.openapi(
    meRoute,
    (context) =>
      run(context, (member) =>
        member.repository.getAccount(member.member),
      ) as never,
  );
  secure(patchProfileRoute, true);
  app.openapi(
    patchProfileRoute,
    (context) =>
      run(context, (member) =>
        member.repository.patchProfile(
          member.member,
          context.req.valid("json"),
          versionFrom(context.req.header("if-match"))!,
        ),
      ) as never,
  );
  secure(getPreferencesRoute, false);
  app.openapi(
    getPreferencesRoute,
    (context) =>
      run(context, (member) =>
        member.repository.getPreferences(member.member),
      ) as never,
  );
  secure(patchPreferencesRoute, true);
  app.openapi(
    patchPreferencesRoute,
    (context) =>
      run(context, (member) =>
        member.repository.patchPreferences(
          member.member,
          context.req.valid("json"),
          versionFrom(context.req.header("if-match"))!,
        ),
      ) as never,
  );
  secure(getOnboardingRoute, false);
  app.openapi(
    getOnboardingRoute,
    (context) =>
      run(context, (member) =>
        member.repository.getOnboarding(member.member),
      ) as never,
  );
  secure(patchOnboardingRoute, true);
  app.openapi(
    patchOnboardingRoute,
    (context) =>
      run(context, (member) =>
        member.repository.patchOnboarding(
          member.member,
          context.req.valid("json"),
          versionFrom(context.req.header("if-match"))!,
        ),
      ) as never,
  );
  secure(getAstrologyRoute, false);
  app.openapi(
    getAstrologyRoute,
    (context) =>
      optional(context, (member) =>
        member.repository.getAstrologyProfile(member.member),
      ) as never,
  );
  secure(putAstrologyRoute, true);
  app.openapi(
    putAstrologyRoute,
    (context) =>
      run(context, (member) =>
        member.repository.putAstrologyProfile(
          member.member,
          context.req.valid("json"),
          versionFrom(context.req.header("if-match")),
        ),
      ) as never,
  );
  secure(deleteAstrologyRoute, true);
  app.openapi(deleteAstrologyRoute, async (context) => {
    const member = access(context);
    if (member === undefined) return unavailable(context) as never;
    try {
      await member.repository.deleteAstrologyProfile(
        member.member,
        versionFrom(context.req.header("if-match")),
      );
      return context.body(null, 204) as never;
    } catch (error) {
      return error instanceof VersionConflictError
        ? (errorResponse(
            context,
            409,
            "version_conflict",
            "This resource changed. Refresh before retrying.",
          ) as never)
        : (unavailable(context) as never);
    }
  });
  secure(getInvestorRoute, false);
  app.openapi(
    getInvestorRoute,
    (context) =>
      optional(context, (member) =>
        member.repository.getInvestorProfile(member.member),
      ) as never,
  );
  secure(putInvestorRoute, true);
  app.openapi(
    putInvestorRoute,
    (context) =>
      run(context, (member) =>
        member.repository.putInvestorProfile(
          member.member,
          context.req.valid("json"),
          versionFrom(context.req.header("if-match")),
        ),
      ) as never,
  );
  secure(postConsentRoute, true);
  app.openapi(
    postConsentRoute,
    (context) =>
      run(context, (member) =>
        member.repository.createConsent(
          member.member,
          context.req.valid("json"),
        ),
      ) as never,
  );
}

function responseVersion(data: unknown): number | undefined {
  if (typeof data !== "object" || data === null) return undefined;
  if ("version" in data && typeof data.version === "number")
    return data.version;
  if (
    "profile" in data &&
    typeof data.profile === "object" &&
    data.profile !== null &&
    "version" in data.profile &&
    typeof data.profile.version === "number"
  ) {
    return data.profile.version;
  }
  return undefined;
}

function unavailable(context: any) {
  return errorResponse(
    context,
    503,
    "service_unavailable",
    "Member storage is temporarily unavailable.",
    { retryable: true },
  );
}
