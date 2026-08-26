import { rowanCounselSchema } from "../editorial/schemas.ts";
import type { MemberRequestContext } from "../editorial/repository.ts";
import type { RowanRepository } from "./repository.ts";

export async function resolveReviewedCounsel(
  repository: RowanRepository,
  member: MemberRequestContext,
  input: {
    surface: "daily_ritual" | "evidence" | "asset_codex" | "coven";
    contextCode: string;
    resourceId?: string;
  },
) {
  const counsel = await repository.resolveRowan(member, input);
  return counsel === null ? null : rowanCounselSchema.parse(counsel);
}
