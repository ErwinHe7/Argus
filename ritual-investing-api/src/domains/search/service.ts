export type SearchKind = "asset" | "coven" | "grimoire" | "circle_template";

export function parseSearchKinds(value: string): SearchKind[] {
  return [...new Set(value.split(","))] as SearchKind[];
}
