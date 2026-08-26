import type { OpenAPIHono } from "@hono/zod-openapi";

import type { AppEnvironment } from "../app.ts";

export function buildOpenApiDocument(app: OpenAPIHono<AppEnvironment>) {
  const document = app.getOpenAPIDocument({
    openapi: "3.0.3",
    info: {
      title: "Ritual Investing API",
      version: "1.0.0",
      description:
        "Contract for deterministic research, private member state, simulated investing, and audited staff operations.",
    },
    servers: [{ url: "https://api.ritual-investing.example" }],
  });

  document.components = {
    ...document.components,
    securitySchemes: {
      ...document.components?.securitySchemes,
      Auth0OAuth: {
        type: "oauth2",
        description:
          "Auth0 Authorization Code with PKCE access token for the Ritual API audience.",
        flows: {
          authorizationCode: {
            authorizationUrl: "https://YOUR_AUTH0_DOMAIN/authorize",
            tokenUrl: "https://YOUR_AUTH0_DOMAIN/oauth/token",
            scopes: {
              "read:self": "Read the member's own Ritual data.",
              "write:self": "Update the member's own Ritual data.",
              "simulate:self": "Run deterministic Demo commands.",
              "privacy:self": "Run export and deletion requests.",
              "admin:operations:read":
                "Read bounded staff operational metadata.",
              "admin:operations:write":
                "Retry bounded operational work with audit evidence.",
              "admin:privacy:read":
                "Read minimized privacy operation metadata.",
              "admin:privacy:write":
                "Retry verified privacy work with audit evidence.",
              "admin:media:read": "Read approved media metadata.",
              "admin:media:write":
                "Manage quarantined media upload intents and approved derivatives.",
              "admin:editorial:read": "Read staff editorial drafts and reviews.",
              "admin:editorial:write": "Create and edit staff editorial drafts.",
              "admin:editorial:review": "Record editorial review decisions.",
              "admin:editorial:publish":
                "Publish or withdraw approved editorial truth.",
              "admin:audit:read": "Read immutable redacted staff audit history.",
              "admin:catalog:read": "Read global editorial catalog records.",
              "admin:catalog:write": "Create and update global editorial catalog records.",
              "admin:coven:verify": "Record high-trust Coven verification decisions.",
              "admin:moderation:read": "Read redacted content moderation metadata.",
              "admin:moderation:write": "Open and resolve audited moderation cases.",
            },
          },
        },
      },
      CloudflareAccess: {
        type: "apiKey",
        in: "header",
        name: "Cf-Access-Jwt-Assertion",
        description:
          "Cloudflare Access application assertion required in addition to the Auth0 API token.",
      },
    },
    parameters: {
      ...document.components?.parameters,
      IdempotencyKey: {
        name: "idempotency-key",
        in: "header",
        required: true,
        schema: {
          type: "string",
          minLength: 16,
          maxLength: 64,
          pattern: "^[\\x21-\\x7E]{16,64}$",
        },
      },
    },
    responses: {
      ...document.components?.responses,
      ValidationError: {
        description: "The request failed strict boundary validation.",
        content: {
          "application/json": {
            schema: { $ref: "#/components/schemas/ErrorResponse" },
          },
        },
      },
      Unauthorized: {
        description: "A valid member access token is required.",
        content: {
          "application/json": {
            schema: { $ref: "#/components/schemas/ErrorResponse" },
          },
        },
      },
      RateLimited: {
        description: "The applicable route and actor quota was exceeded.",
        headers: {
          "Retry-After": { schema: { type: "integer", minimum: 1 } },
        },
        content: {
          "application/json": {
            schema: { $ref: "#/components/schemas/ErrorResponse" },
          },
        },
      },
    },
  };

  return document;
}
