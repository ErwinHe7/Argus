export function parsePagePosition(
  value: string | undefined,
): [string | null, string | null] {
  if (value === undefined) return [null, null];
  const separator = value.lastIndexOf("|");
  if (separator <= 0) throw new Error("invalid_cursor_position");
  return [value.slice(0, separator), value.slice(separator + 1)];
}
