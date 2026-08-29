import type { JsonObject } from "../../db/repository-support.ts";

export interface MediaRepository {
  createUploadIntent(
    input: Readonly<{
      mimeType: "image/jpeg" | "image/png" | "image/webp";
      maxBytes: number;
      expiresAt: Date;
    }>,
  ): Promise<JsonObject>;
  getUploadIntent(id: string): Promise<JsonObject>;
  finalizeUpload(
    intentId: string,
    byteSize: number,
    checksum: string,
  ): Promise<JsonObject>;
  getAsset(id: string): Promise<JsonObject>;
}
