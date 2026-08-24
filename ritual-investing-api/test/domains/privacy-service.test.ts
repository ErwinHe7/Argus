import { describe, expect, it } from "vitest";

import {
  buildDeletionDenyEntry,
  buildExportManifest,
  buildStreamingPrivacyZip,
  verifyDeletionDenyEntry,
} from "../../src/domains/privacy/service";

describe("privacy artifacts", () => {
  it("builds a versioned, deterministic, tenant-bound, secret-free export manifest", async () => {
    const rows = {
      profile: [{ tenant_id: "tenant-a", display_name: "Member" }],
      devices: [
        {
          tenant_id: "tenant-a",
          platform: "ios",
          push_token_ciphertext: "never-export",
          push_token_hash: "never-export",
        },
      ],
    };
    const manifest = await buildExportManifest({
      tenantId: "tenant-a",
      requestId: "request-a",
      snapshotAt: "2026-08-24T10:00:00.000Z",
      sourceSequence: 42,
      rows,
    });
    expect(manifest.schema_version).toBe(1);
    expect(manifest.source_sequence).toBe(42);
    expect(JSON.stringify(manifest)).not.toContain("never-export");
    expect(JSON.stringify(manifest)).not.toMatch(/push_token/i);
    expect(
      await buildExportManifest({
        tenantId: "tenant-a",
        requestId: "request-a",
        snapshotAt: "2026-08-24T10:00:00.000Z",
        sourceSequence: 42,
        rows,
      }),
    ).toEqual(manifest);
  });

  it("checksums an append-only deletion denial independently of Neon", async () => {
    const entry = await buildDeletionDenyEntry({
      tombstoneId: "018f3c2a-4b67-7a89-8abc-123456789001",
      tenantId: "018f3c2a-4b67-7a89-8abc-123456789002",
      subjectHash: "b".repeat(64),
      effectiveAt: "2026-08-24T10:00:00.000Z",
      purgeGeneration: 3,
    });
    expect(entry.key).toBe(
      "deletion-deny/v1/018f3c2a-4b67-7a89-8abc-123456789001/3.json",
    );
    expect(await verifyDeletionDenyEntry(entry.body, entry.checksum)).toBe(
      true,
    );
    expect(
      await verifyDeletionDenyEntry(
        entry.body.replace("tenant_id", "other_tenant"),
        entry.checksum,
      ),
    ).toBe(false);
  });

  it("streams every export row through bounded deterministic pages", async () => {
    const rows = Array.from({ length: 5 }, (_, index) => ({
      id: index,
      display_name: `Member ${index}`,
      push_token_ciphertext: "never-export",
    }));
    const offsets: number[] = [];
    const archive = buildStreamingPrivacyZip({
      tenantId: "tenant-a",
      requestId: "request-a",
      snapshotAt: "2026-08-24T10:00:00.000Z",
      sourceSequence: 42,
      pageSize: 2,
      collections: [
        {
          name: "profiles",
          readPage: async (offset, limit) => {
            offsets.push(offset);
            return rows.slice(offset, offset + limit);
          },
        },
      ],
    });
    const reader = archive.body.getReader();
    const chunks: Uint8Array[] = [];
    for (;;) {
      const next = await reader.read();
      if (next.done) break;
      chunks.push(next.value);
    }
    const bytes = new Uint8Array(
      chunks.reduce((total, chunk) => total + chunk.length, 0),
    );
    let cursor = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, cursor);
      cursor += chunk.length;
    }
    const completed = await archive.completion;
    const readable = new TextDecoder().decode(bytes);
    expect(offsets).toEqual([0, 2, 4]);
    expect([...bytes.slice(0, 2)]).toEqual([0x50, 0x4b]);
    expect(readable).toContain("Member 4");
    expect(readable).not.toContain("never-export");
    expect(completed.manifest).toMatchObject({
      schema_version: 2,
      collections: { profiles: 5 },
    });
    expect(completed.manifestChecksum).toMatch(/^[a-f0-9]{64}$/);
  });
});
