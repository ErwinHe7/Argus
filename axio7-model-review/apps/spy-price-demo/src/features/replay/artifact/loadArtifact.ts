import type {
  Manifest,
  SessionArtifact,
  SessionIndexArtifact,
  SessionIndexEntry,
} from "./generated/contracts";
import { ArtifactError } from "./ArtifactError";
import {
  validateManifest,
  validateSession,
  validateSessionIndex,
} from "./validateArtifact";

export interface ReplayLoaders {
  loadManifest(signal?: AbortSignal): Promise<Manifest>;
  loadSessionIndex(
    manifest: Manifest,
    signal?: AbortSignal,
  ): Promise<SessionIndexArtifact>;
  loadSession(
    entry: SessionIndexEntry,
    signal?: AbortSignal,
  ): Promise<SessionArtifact>;
}

function isAbortError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "name" in error &&
    error.name === "AbortError"
  );
}

async function sha256Hex(body: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", body);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

export function createReplayLoaders(base?: string): ReplayLoaders {
  const configuredArtifactBase =
    base ?? import.meta.env.VITE_SPY_ARTIFACT_BASE;
  if (!configuredArtifactBase) {
    throw new Error("VITE_SPY_ARTIFACT_BASE is required");
  }
  const artifactBase = configuredArtifactBase.replace(/\/+$/, "");
  const sessionArtifactHashes = new WeakMap<SessionIndexEntry, string>();

  async function getJson(
    path: string,
    expectedSha256?: string,
    signal?: AbortSignal,
  ): Promise<unknown> {
    let response: Response;
    try {
      response = await fetch(
        `${artifactBase}/${path}`,
        signal === undefined ? {} : { signal },
      );
    } catch (error) {
      if (isAbortError(error)) throw error;
      throw ArtifactError.network(path, error);
    }

    if (!response.ok) {
      throw ArtifactError.fromResponse(path, response.status);
    }

    let body: Uint8Array<ArrayBuffer>;
    try {
      body = new Uint8Array(await response.arrayBuffer());
    } catch (error) {
      if (isAbortError(error)) throw error;
      throw ArtifactError.network(path, error);
    }

    if (expectedSha256 && (await sha256Hex(body)) !== expectedSha256) {
      throw ArtifactError.hashMismatch(path);
    }

    try {
      const text = new TextDecoder("utf-8", { fatal: true }).decode(body);
      return JSON.parse(text) as unknown;
    } catch (error) {
      throw ArtifactError.invalidJson(path, error);
    }
  }

  async function instanceLoadManifest(
    signal?: AbortSignal,
  ): Promise<Manifest> {
    return validateManifest(
      await getJson("manifest.json", undefined, signal),
    );
  }

  async function instanceLoadSessionIndex(
    manifest: Manifest,
    signal?: AbortSignal,
  ): Promise<SessionIndexArtifact> {
    const index = validateSessionIndex(
      await getJson(
        manifest.session_index.path,
        manifest.session_index.sha256,
        signal,
      ),
    );
    if (index.artifact_sha256 !== manifest.artifact_sha256) {
      throw ArtifactError.hashMismatch(manifest.session_index.path, {
        relation: "manifest-to-index",
      });
    }

    for (const entry of index.sessions) {
      sessionArtifactHashes.set(entry, index.artifact_sha256);
    }
    return index;
  }

  async function instanceLoadSession(
    entry: SessionIndexEntry,
    signal?: AbortSignal,
  ): Promise<SessionArtifact> {
    const expectedArtifactSha256 = sessionArtifactHashes.get(entry);
    if (expectedArtifactSha256 === undefined) {
      throw ArtifactError.hashMismatch(entry.path, {
        relation: "index-to-session",
      });
    }

    const session = validateSession(
      await getJson(entry.path, entry.sha256, signal),
    );
    if (session.provenance.artifact_sha256 !== expectedArtifactSha256) {
      throw ArtifactError.hashMismatch(entry.path, {
        relation: "index-to-session",
      });
    }
    return session;
  }

  return {
    loadManifest: instanceLoadManifest,
    loadSession: instanceLoadSession,
    loadSessionIndex: instanceLoadSessionIndex,
  };
}

export const defaultReplayLoaders = createReplayLoaders();

export function loadManifest(signal?: AbortSignal): Promise<Manifest> {
  return defaultReplayLoaders.loadManifest(signal);
}

export function loadSessionIndex(
  manifest: Manifest,
  signal?: AbortSignal,
): Promise<SessionIndexArtifact> {
  return defaultReplayLoaders.loadSessionIndex(manifest, signal);
}

export function loadSession(
  entry: SessionIndexEntry,
  signal?: AbortSignal,
): Promise<SessionArtifact> {
  return defaultReplayLoaders.loadSession(entry, signal);
}

export default defaultReplayLoaders;
