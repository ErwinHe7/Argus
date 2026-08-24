import { createHash } from "node:crypto";

type Document = {
  paths: Record<string, unknown>;
  components?: { schemas?: Record<string, unknown> };
};

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => `${JSON.stringify(key)}:${canonical(child)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function structuralSchema(
  document: Document,
  value: unknown,
  visited: ReadonlySet<string> = new Set(),
): unknown {
  if (value === null || typeof value !== "object") return value;
  const schema = value as Record<string, unknown>;
  if (typeof schema.$ref === "string") {
    const reference = schema.$ref;
    if (visited.has(reference)) return { $ref: reference };
    const name = reference.match(/^#\/components\/schemas\/(.+)$/)?.[1];
    const resolved =
      name === undefined ? undefined : document.components?.schemas?.[name];
    if (resolved === undefined)
      throw new Error(`unresolved compatibility schema ${reference}`);
    return structuralSchema(
      document,
      resolved,
      new Set([...visited, reference]),
    );
  }
  const properties =
    schema.properties !== null && typeof schema.properties === "object"
      ? Object.fromEntries(
          Object.entries(schema.properties as Record<string, unknown>)
            .sort(([left], [right]) => left.localeCompare(right))
            .map(([name, child]) => [
              name,
              structuralSchema(document, child, visited),
            ]),
        )
      : undefined;
  const variants = (name: "allOf" | "anyOf" | "oneOf") =>
    Array.isArray(schema[name])
      ? schema[name].map((child) => structuralSchema(document, child, visited))
      : undefined;
  return {
    ...(schema.type === undefined ? {} : { type: schema.type }),
    ...(schema.format === undefined ? {} : { format: schema.format }),
    ...(schema.nullable === undefined ? {} : { nullable: schema.nullable }),
    ...(schema.enum === undefined ? {} : { enum: schema.enum }),
    ...(schema.required === undefined
      ? {}
      : { required: [...(schema.required as string[])].sort() }),
    ...(properties === undefined ? {} : { properties }),
    ...(schema.items === undefined
      ? {}
      : { items: structuralSchema(document, schema.items, visited) }),
    ...(variants("allOf") === undefined ? {} : { allOf: variants("allOf") }),
    ...(variants("anyOf") === undefined ? {} : { anyOf: variants("anyOf") }),
    ...(variants("oneOf") === undefined ? {} : { oneOf: variants("oneOf") }),
    ...(typeof schema.additionalProperties === "object"
      ? {
          additionalProperties: structuralSchema(
            document,
            schema.additionalProperties,
            visited,
          ),
        }
      : {}),
  };
}

export function fingerprintOperationContract(
  document: Document,
  input: {
    path: string;
    method: string;
    requiredResponses: readonly number[];
  },
): string {
  const operation = (
    document.paths[input.path] as
      | Record<string, Record<string, unknown>>
      | undefined
  )?.[input.method];
  if (operation === undefined)
    throw new Error(`operation ${input.method} ${input.path} is missing`);
  const parameters = Array.isArray(operation.parameters)
    ? operation.parameters
        .map((parameter) => parameter as Record<string, unknown>)
        .map((parameter) => ({
          name: parameter.name,
          in: parameter.in,
          required: parameter.required === true,
          schema: structuralSchema(document, parameter.schema),
        }))
        .sort((left, right) =>
          `${left.in}:${left.name}`.localeCompare(`${right.in}:${right.name}`),
        )
    : [];
  const requestBody = operation.requestBody as
    | Record<string, unknown>
    | undefined;
  const requestContent = requestBody?.content as
    | Record<string, unknown>
    | undefined;
  const responses = operation.responses as Record<string, unknown> | undefined;
  const shape = {
    parameters,
    request: {
      required: requestBody?.required === true,
      content: Object.fromEntries(
        Object.entries(requestContent ?? {}).map(([mediaType, media]) => [
          mediaType,
          structuralSchema(document, (media as Record<string, unknown>).schema),
        ]),
      ),
    },
    responses: Object.fromEntries(
      [...input.requiredResponses]
        .sort((a, b) => a - b)
        .map((status) => {
          const response = responses?.[String(status)] as
            | Record<string, unknown>
            | undefined;
          if (response === undefined)
            throw new Error(
              `${input.method} ${input.path} lost response ${status}`,
            );
          const content = response.content as
            | Record<string, unknown>
            | undefined;
          return [
            status,
            Object.fromEntries(
              Object.entries(content ?? {}).map(([mediaType, media]) => [
                mediaType,
                structuralSchema(
                  document,
                  (media as Record<string, unknown>).schema,
                ),
              ]),
            ),
          ];
        }),
    ),
  };
  return createHash("sha256").update(canonical(shape)).digest("hex");
}

export function assertOperationFingerprint(
  document: Document,
  operation: {
    path: string;
    method: string;
    required_responses: readonly number[];
    contract_fingerprint: string;
  },
): void {
  const actual = fingerprintOperationContract(document, {
    path: operation.path,
    method: operation.method,
    requiredResponses: operation.required_responses,
  });
  if (actual !== operation.contract_fingerprint)
    throw new Error(
      `${operation.method} ${operation.path} broke the released mobile contract`,
    );
}
