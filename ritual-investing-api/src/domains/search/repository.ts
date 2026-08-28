import type { DiscoverRepository } from "../editorial/repository.ts";

export type SearchRepository = Pick<DiscoverRepository, "search">;
export { createSupabaseSearchRepository } from "../../db/supabase-repositories.ts";
