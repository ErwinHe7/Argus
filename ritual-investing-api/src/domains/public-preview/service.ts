import type { PublicContentRepository } from "../editorial/repository.ts";

export async function loadPublicDaily(
  repository: PublicContentRepository,
  date: string,
  mode: "tarot" | "astrology",
) {
  const revisionId = await repository.resolveDailyRevision({ date, mode });
  return revisionId === null ? null : { revisionId, load: () => repository.loadDaily({ date, mode }, revisionId) };
}
