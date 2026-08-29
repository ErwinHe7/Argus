import type { DatabaseTransaction } from "../../db/database-port.ts";
import { type JsonObject } from "../../db/repository-support.ts";

export function createSupabaseRowanRepository(
  database: DatabaseTransaction,
) {
  return Object.freeze({
    resolve: async (surface: string, contextKey: string) => {
      const result = await database.query<JsonObject>(
        `select script.id, script.script_key, binding.priority,
                  revision.body_template, revision.allowed_tokens,
                  revision.risk_footer
             from argus_app.rowan_context_bindings binding
             join argus_app.rowan_scripts script on script.id = binding.script_id
             join argus_app.editorial_items item
               on item.id = script.editorial_item_id
             join argus_app.rowan_script_revisions revision
               on revision.revision_id = item.current_published_revision_id
            where binding.surface = $1 and binding.context_key = $2
              and item.status = 'published'
            order by binding.priority
            limit 1`,
        [surface, contextKey],
      );
      return result.rows[0] ?? null;
    },
  });
}
