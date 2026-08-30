import { describe, expect, it } from "vitest";

import {
  createBetaDraftStarpathCapabilityEvaluator,
  createDraftPreviewStarpathRepository,
  draftPreviewStarpathManifestVersion,
} from "../../src/domains/starpath/draft-preview-repository.ts";
import { StarpathError } from "../../src/domains/starpath/ports.ts";
import { starpathSnapshotSchema } from "../../src/domains/starpath/schemas.ts";

describe("Starpath draft beta preview", () => {
  it("serves the complete eight-node curriculum as read-only draft content", async () => {
    const repository = createDraftPreviewStarpathRepository();
    const snapshot = await repository.read();

    expect(() => starpathSnapshotSchema.parse(snapshot)).not.toThrow();
    expect(snapshot.authority.manifest_version).toBe(
      draftPreviewStarpathManifestVersion,
    );
    expect(snapshot.availability).toBe("available");
    expect(snapshot.session).toMatchObject({
      state: "active",
      explicit_start: false,
    });
    expect(snapshot.progress).toMatchObject({
      current_node_ordinal: 1,
      version: 1,
    });
    expect(snapshot.theme).not.toBeNull();
    expect(snapshot.nodes.map((node) => node.title)).toEqual([
      "The Share Sigil",
      "The Market Lantern",
      "The Many-Star Shield",
      "The Fee Eclipse",
      "The Filing Grimoire",
      "The Fund and Bond Map",
      "The False Sun",
      "The Verification Compass",
    ]);
    expect(snapshot.nodes).toHaveLength(8);
    expect(snapshot.nodes.every((node) =>
      node.factual_sections.length > 0 &&
      node.factual_sections.every((section) => section.evidence.length > 0) &&
      node.knowledge_check.options.length >= 2
    )).toBe(true);
  });

  it("rejects progress mutations while the curriculum remains a draft", async () => {
    const repository = createDraftPreviewStarpathRepository();

    await expect(repository.startOrResume("draft-preview-key")).rejects
      .toEqual(new StarpathError("starpath_unavailable"));
  });

  it("advertises the preview only through a short-lived beta decision", async () => {
    const now = new Date("2026-08-30T12:00:00.000Z");
    const evaluator = createBetaDraftStarpathCapabilityEvaluator(() => now);

    await expect(evaluator.evaluate("starpath.read")).resolves.toMatchObject({
      branch: "starpath",
      available: true,
      environment: "beta",
      jurisdiction: "US",
      capabilityVersion: 1,
      evaluatedAt: "2026-08-30T12:00:00.000Z",
      expiresAt: "2026-08-30T12:05:00.000Z",
    });
  });
});
