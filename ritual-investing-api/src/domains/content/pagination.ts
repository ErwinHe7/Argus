import { z } from "@hono/zod-openapi";

import {
  type CursorPosition,
  decodeOpaqueCursor,
  encodeOpaqueCursor,
  InvalidOpaqueCursorError,
  type OpaqueCursorBinding,
} from "../../contracts/opaque-cursor.ts";
import { HttpBoundaryError } from "../retained-http/boundary.ts";
import { pageLimitSchema } from "../retained-http/schemas.ts";

export const pagedContentQuery = z.object({
  cursor: z.string().min(1).max(2_048).optional(),
  limit: pageLimitSchema.optional(),
}).strict();

export type KeysetPageRequest =
  & OpaqueCursorBinding
  & Readonly<{ cursor?: string }>;

export function cursorFilterIdentity(
  filters: Readonly<Record<string, string | null | undefined>>,
): string {
  return Object.entries(filters)
    .filter((entry): entry is [string, string | null] => entry[1] !== undefined)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) =>
      `${encodeURIComponent(key)}=${encodeURIComponent(value ?? "")}`
    )
    .join("&");
}

function invalidCursor(): never {
  throw new HttpBoundaryError(
    422,
    "invalid_cursor",
    "The pagination cursor is invalid or stale.",
  );
}

export async function keysetPosition(
  request: KeysetPageRequest,
): Promise<CursorPosition | null> {
  if (request.cursor === undefined) return null;
  try {
    return await decodeOpaqueCursor(request.cursor, request);
  } catch (error) {
    if (error instanceof InvalidOpaqueCursorError) invalidCursor();
    throw error;
  }
}

export async function typedKeysetPosition<T extends CursorPosition>(
  request: KeysetPageRequest,
  schema: z.ZodType<T>,
): Promise<T | null> {
  const position = await keysetPosition(request);
  if (position === null) return null;
  const parsed = schema.safeParse(position);
  if (!parsed.success) invalidCursor();
  return parsed.data;
}

export async function keysetPage<T>(
  request: KeysetPageRequest,
  overfetchedItems: readonly T[],
  position: (item: T) => CursorPosition,
): Promise<Readonly<{ items: readonly T[]; nextCursor: string | null }>> {
  if (overfetchedItems.length > request.pageSize + 1) {
    throw new Error("keyset_page_overfetch_exceeded");
  }
  const hasMore = overfetchedItems.length > request.pageSize;
  const items = overfetchedItems.slice(0, request.pageSize);
  const last = items.at(-1);
  const nextCursor = hasMore && last !== undefined
    ? await encodeOpaqueCursor({ ...request, position: position(last) })
    : null;
  return Object.freeze({ items, nextCursor });
}
