import { decodeCursor, encodeCursor } from "./cursor.ts";
import type { PageResult } from "./repository.ts";

export async function resolveSignedPage<T>(input: {
  cursor?: string;
  secret: string;
  scope: string;
  load: (after: string | undefined) => Promise<PageResult<T>>;
}) {
  const after = await decodeCursor(input.secret, input.scope, input.cursor);
  const result = await input.load(after);
  return {
    items: result.items,
    nextCursor: result.nextPosition === null
      ? null
      : await encodeCursor(input.secret, input.scope, result.nextPosition),
  };
}
