import type { RitualRepository } from "../editorial/repository.ts";

export type RowanRepository = Pick<RitualRepository, "resolveRowan">;
export { createSupabaseRowanRepository } from "../../db/supabase-repositories.ts";
