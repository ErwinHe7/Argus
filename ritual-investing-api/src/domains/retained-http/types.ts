import type { VerifiedRequestClaims } from "../../db/request-claims.ts";

export type VerifiedSupabasePrincipal = Readonly<{
  userId: string;
  sessionId: string;
  aal: "aal1" | "aal2";
  issuedAt: number;
  authenticatedAt?: number;
}>;

export type RetainedRuntimeBindings = Readonly<{
  environment: "development" | "test" | "staging" | "production";
  buildRevision: string;
  consumerOrigin: string;
  adminOrigin: string;
}>;

export type RetainedVariables = {
  requestId: string;
  principal: VerifiedSupabasePrincipal;
  claims: VerifiedRequestClaims;
  repositorySet: unknown;
  publicPreviewRepository: unknown;
};

export type RetainedAppEnvironment = {
  Bindings: RetainedRuntimeBindings;
  Variables: RetainedVariables;
};

export type RetainedTelemetryEvent = Readonly<{
  event: "http.request";
  requestId: string;
  method: string;
  route: string;
  status: number;
  latencyMs: number;
}>;
