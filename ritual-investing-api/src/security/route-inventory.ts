type OpenApiOperation = {
  security?: Array<Record<string, string[]>>;
  operationId?: string;
  tags?: string[];
};

type OpenApiDocument = {
  paths: Record<string, unknown>;
};

const HTTP_METHODS = new Set(["get", "post", "put", "patch", "delete"]);

export type AuthorizationMatrixEntry = {
  path: string;
  method: string;
  actor: "member" | "admin";
  permissions: string[];
  identityOnly: boolean;
};

export type ResourcePathMatrixEntry = {
  operationId: string;
  path: string;
  method: string;
  parameters: string[];
  scope: "public" | "tenant" | "admin";
  enforcement:
    | "published-revision-allowlist"
    | "tenant-context-and-rls"
    | "staff-permission-and-role";
  guardOwner: string;
  parentChildGuard: boolean;
};

const REVIEWED_PARENT_CHILD_SIGNATURES = new Set([
  "asset_id,id",
  "intention_id,run_id",
  "item_id,revision_id",
]);

function operations(document: OpenApiDocument) {
  return Object.entries(document.paths).flatMap(([path, pathItem]) =>
    Object.entries(
      typeof pathItem === "object" && pathItem !== null
        ? (pathItem as Record<string, unknown>)
        : {},
    )
      .filter(
        ([method, operation]) =>
          HTTP_METHODS.has(method) &&
          typeof operation === "object" &&
          operation !== null,
      )
      .map(([method, operation]) => ({
        path,
        method: method.toUpperCase(),
        operation: operation as OpenApiOperation,
      })),
  );
}

export function buildAuthorizationMatrix(
  document: OpenApiDocument,
): AuthorizationMatrixEntry[] {
  return operations(document).flatMap(({ path, method, operation }) => {
    if (!Array.isArray(operation.security) || operation.security.length === 0)
      return [];
    const permissions = [
      ...new Set(
        operation.security.flatMap(
          (requirement) => requirement.Auth0OAuth ?? [],
        ),
      ),
    ].sort();
    return [
      {
        path,
        method,
        actor:
          path.startsWith("/v1/admin/") ||
          operation.security.some((requirement) =>
            Object.hasOwn(requirement, "CloudflareAccess"),
          )
            ? ("admin" as const)
            : ("member" as const),
        permissions,
        identityOnly: permissions.length === 0,
      },
    ];
  });
}

export function buildResourcePathMatrix(
  document: OpenApiDocument,
): ResourcePathMatrixEntry[] {
  return operations(document).flatMap(({ path, method, operation }) => {
    const parameters = [...path.matchAll(/\{([^}]+)\}/g)].map(
      (match) => match[1]!,
    );
    if (parameters.length === 0) return [];
    const scope = path.startsWith("/v1/public/")
      ? ("public" as const)
      : path.startsWith("/v1/admin/")
        ? ("admin" as const)
        : ("tenant" as const);
    const operationId = operation.operationId;
    const guardOwner = operation.tags?.[0];
    if (!operationId || !guardOwner) {
      throw new Error(
        `${method.toUpperCase()} ${path} lacks guard ownership metadata`,
      );
    }
    return [
      {
        operationId,
        path,
        method,
        parameters,
        scope,
        enforcement:
          scope === "public"
            ? ("published-revision-allowlist" as const)
            : scope === "admin"
              ? ("staff-permission-and-role" as const)
              : ("tenant-context-and-rls" as const),
        guardOwner,
        parentChildGuard:
          parameters.length > 1 &&
          REVIEWED_PARENT_CHILD_SIGNATURES.has(
            [...parameters].sort().join(","),
          ),
      },
    ];
  });
}
