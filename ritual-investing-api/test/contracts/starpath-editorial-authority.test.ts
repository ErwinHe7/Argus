import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const repositoryRoot = resolve(import.meta.dirname, "../../..");
const migrationRoot = resolve(repositoryRoot, "supabase/migrations");

function migrationAuthority(): string {
  return readdirSync(migrationRoot)
    .filter((path) => path.endsWith(".sql"))
    .sort()
    .map((path) => readFileSync(resolve(migrationRoot, path), "utf8"))
    .join("\n");
}

describe("Starpath editorial authority", () => {
  it("normalizes the reviewed lesson and atomic curriculum boundary", () => {
    const sql = migrationAuthority();

    for (const relation of [
      "starpath_policies",
      "starpath_lessons",
      "starpath_lesson_revisions",
      "starpath_factual_sections",
      "starpath_knowledge_checks",
      "starpath_knowledge_check_options",
      "starpath_evidence_bindings",
      "starpath_session_themes",
      "starpath_curriculum_manifests",
      "starpath_manifest_nodes",
      "starpath_manifest_themes",
    ]) {
      expect(sql, relation).toMatch(
        new RegExp(`create table argus_app\\.${relation}\\b`, "i"),
      );
    }

    expect(sql).toMatch(/kind in \([^)]*'starpath_lesson'/s);
    expect(sql).toMatch(/discipline text not null default 'general'/);
    expect(sql).toMatch(/sealed_content_hash text/);
    expect(sql).toMatch(/policy_version text/);
  });

  it("exposes typed commands for validation, dual review, and publication", () => {
    const sql = migrationAuthority();

    for (const routine of [
      "validate_starpath_member_copy",
      "sync_starpath_revision",
      "submit_starpath_revision",
      "decide_starpath_review",
      "publish_starpath_manifest",
    ]) {
      expect(sql, routine).toMatch(
        new RegExp(`function argus_private\\.${routine}\\b`, "i"),
      );
    }

    expect(sql).toContain("editorial:review:factual");
    expect(sql).toContain("editorial:review:compliance");
    expect(sql).toContain("education_general");
  });
});
