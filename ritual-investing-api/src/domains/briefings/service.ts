import type { BriefingRepository } from "./repository.ts";

export async function readDailyBriefing(
  repository: Pick<BriefingRepository, "daily">,
  member: Parameters<BriefingRepository["daily"]>[0],
  localDate: string,
) {
  // Deliberately projection-only: GET must never perform heavy generation.
  return repository.daily(member, localDate);
}
