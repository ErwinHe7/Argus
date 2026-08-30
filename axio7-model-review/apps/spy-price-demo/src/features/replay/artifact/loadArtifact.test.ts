import fixtureManifest from "../../../../public/fixtures/spy-demo/manifest.json";
import fixtureSession from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import fixtureSessionIndex from "../../../../public/fixtures/spy-demo/sessions/index.json";
import { ArtifactError } from "./ArtifactError";
import {
  createReplayLoaders,
  loadManifest,
  loadSession,
  loadSessionIndex,
} from "./loadArtifact";
import { validateManifest } from "./validateArtifact";
import type {
  Manifest,
  SessionArtifact,
  SessionIndexEntry,
} from "./generated/contracts";

const fetchMock = vi.fn<typeof fetch>();

function jsonBody(value: unknown): string {
  return JSON.stringify(value);
}

function jsonResponse(value: unknown, status = 200): Response {
  return new Response(jsonBody(value), {
    headers: { "content-type": "application/json" },
    status,
  });
}

function fixtureFileResponse(value: unknown): Response {
  return new Response(`${jsonBody(value)}\n`, {
    headers: { "content-type": "application/json" },
  });
}

async function sha256Hex(body: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(body),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

async function captureArtifactError(
  operation: () => Promise<unknown>,
): Promise<ArtifactError> {
  try {
    await operation();
  } catch (error) {
    expect(error).toBeInstanceOf(ArtifactError);
    if (error instanceof ArtifactError) return error;
    throw error;
  }

  throw new Error("Expected an ArtifactError");
}

async function loadMutatedAuthenticatedSession(
  session: SessionArtifact,
  options: {
    entry?: Partial<SessionIndexEntry>;
    manifest?: Partial<Manifest>;
  } = {},
): Promise<ArtifactError> {
  const sessionBody = jsonBody(session);
  const entry = {
    ...fixtureSessionIndex.sessions[0]!,
    ...options.entry,
    sha256: await sha256Hex(sessionBody),
  };
  const index = {
    ...fixtureSessionIndex,
    sessions: [entry],
  };
  const indexBody = jsonBody(index);
  const manifest = validateManifest({
    ...fixtureManifest,
    ...options.manifest,
    session_index: {
      ...fixtureManifest.session_index,
      sha256: await sha256Hex(indexBody),
    },
  });
  const loaders = createReplayLoaders("/generated");
  fetchMock
    .mockResolvedValueOnce(new Response(indexBody))
    .mockResolvedValueOnce(new Response(sessionBody));
  const validatedIndex = await loaders.loadSessionIndex(manifest);

  return captureArtifactError(() =>
    loaders.loadSession(validatedIndex.sessions[0]!),
  );
}

beforeEach(() => {
  fetchMock.mockReset();
  vi.stubGlobal("fetch", fetchMock);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("artifact loaders", () => {
  it("loads the authenticated chain from generated mode without fixture fallback", async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse(fixtureManifest))
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex))
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSession));

    const manifest = await loadManifest();
    const index = await loadSessionIndex(manifest);
    const session = await loadSession(index.sessions[0]!);

    expect(session.session_date).toBe("2026-07-24");
    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([
      "/generated/manifest.json",
      "/generated/sessions/index.json",
      "/generated/sessions/2026-07-24.json",
    ]);
    expect(fetchMock.mock.calls.flat().join(" ")).not.toContain(
      "/fixtures/spy-demo",
    );
  });

  it("classifies missing manifest, index, and session responses distinctly", async () => {
    const missingManifestLoaders = createReplayLoaders("/generated");
    fetchMock.mockResolvedValueOnce(jsonResponse({}, 404));
    const manifestError = await captureArtifactError(() =>
      missingManifestLoaders.loadManifest(),
    );
    expect(manifestError.code).toBe("MISSING_MANIFEST");
    expect(manifestError.path).toBe("manifest.json");

    const missingIndexLoaders = createReplayLoaders("/generated");
    fetchMock.mockResolvedValueOnce(jsonResponse({}, 404));
    const indexError = await captureArtifactError(() =>
      missingIndexLoaders.loadSessionIndex(validateManifest(fixtureManifest)),
    );
    expect(indexError.code).toBe("MISSING_SESSION_INDEX");
    expect(indexError.path).toBe("sessions/index.json");

    const loaders = createReplayLoaders("/generated");
    fetchMock
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex))
      .mockResolvedValueOnce(jsonResponse({}, 404));
    const index = await loaders.loadSessionIndex(
      validateManifest(fixtureManifest),
    );

    const error = await captureArtifactError(() =>
      loaders.loadSession(index.sessions[0]!),
    );

    expect(error.code).toBe("MISSING_SESSION");
    expect(error.path).toBe("sessions/2026-07-24.json");
  });

  it("maps malformed JSON to INVALID_SCHEMA", async () => {
    fetchMock.mockResolvedValueOnce(new Response("{not-json"));

    const error = await captureArtifactError(() => loadManifest());

    expect(error.code).toBe("INVALID_SCHEMA");
    expect(error.message).not.toContain("not-json");
  });

  it("preserves AbortError without wrapping it", async () => {
    const abortError = new DOMException("stopped", "AbortError");
    fetchMock.mockRejectedValueOnce(abortError);

    await expect(loadManifest()).rejects.toBe(abortError);
  });

  it("maps fetch failures to NETWORK", async () => {
    fetchMock.mockRejectedValueOnce(new TypeError("connection detail"));

    const error = await captureArtifactError(() => loadManifest());

    expect(error.code).toBe("NETWORK");
    expect(error.message).not.toContain("connection detail");
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0]?.[0]).toBe("/generated/manifest.json");
  });

  it("rejects an index whose exact response bytes do not match the manifest hash", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse({ ...fixtureSessionIndex, sessions: [] }),
    );

    const error = await captureArtifactError(() =>
      loadSessionIndex(validateManifest(fixtureManifest)),
    );

    expect(error.code).toBe("HASH_MISMATCH");
  });

  it("rejects session bytes that do not match the validated index entry", async () => {
    const loaders = createReplayLoaders("/generated");
    fetchMock
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex))
      .mockResolvedValueOnce(
        new Response(`${jsonBody(fixtureSession)}\n `),
      );
    const index = await loaders.loadSessionIndex(
      validateManifest(fixtureManifest),
    );

    const error = await captureArtifactError(() =>
      loaders.loadSession(index.sessions[0]!),
    );

    expect(error.code).toBe("HASH_MISMATCH");
  });

  it("rejects an unassociated structural entry before fetching", async () => {
    const loaders = createReplayLoaders("/generated");
    const entry = { ...fixtureSessionIndex.sessions[0]! };

    const error = await captureArtifactError(() =>
      loaders.loadSession(entry),
    );

    expect(error.code).toBe("HASH_MISMATCH");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects a clone of an authenticated entry before fetching", async () => {
    const loaders = createReplayLoaders("/generated");
    fetchMock.mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex));
    const index = await loaders.loadSessionIndex(
      validateManifest(fixtureManifest),
    );
    fetchMock.mockClear();

    const error = await captureArtifactError(() =>
      loaders.loadSession({ ...index.sessions[0]! }),
    );

    expect(error.code).toBe("HASH_MISMATCH");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("keeps authenticated entries isolated between loader instances", async () => {
    const loaderA = createReplayLoaders("/generated-a");
    const loaderB = createReplayLoaders("/generated-b");
    fetchMock.mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex));
    const index = await loaderA.loadSessionIndex(
      validateManifest(fixtureManifest),
    );
    fetchMock.mockClear();

    const error = await captureArtifactError(() =>
      loaderB.loadSession(index.sessions[0]!),
    );

    expect(error.code).toBe("HASH_MISMATCH");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("keeps session correlation tied to the manifest values authenticated with the index", async () => {
    const loaders = createReplayLoaders("/generated");
    const manifest = validateManifest(structuredClone(fixtureManifest));
    fetchMock
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex))
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSession));
    const index = await loaders.loadSessionIndex(manifest);

    manifest.status = "HISTORICAL_OOS";
    manifest.dataset_sha256 = "0".repeat(64);

    await expect(loaders.loadSession(index.sessions[0]!)).resolves.toEqual(
      fixtureSession,
    );
  });

  it("uses the authenticated entry values even if its capability object is mutated", async () => {
    const loaders = createReplayLoaders("/generated");
    fetchMock
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSessionIndex))
      .mockResolvedValueOnce(fixtureFileResponse(fixtureSession));
    const index = await loaders.loadSessionIndex(
      validateManifest(fixtureManifest),
    );
    const entry = index.sessions[0]!;

    entry.date = "2026-07-23";
    entry.path = "sessions/2026-07-23.json";
    entry.rows = 999;
    entry.sha256 = "0".repeat(64);

    await expect(loaders.loadSession(entry)).resolves.toEqual(fixtureSession);
    expect(fetchMock.mock.calls.at(-1)?.[0]).toBe(
      "/generated/sessions/2026-07-24.json",
    );
  });

  it("rejects an index artifact identifier that differs from its manifest", async () => {
    const mismatchedIndex = {
      ...fixtureSessionIndex,
      artifact_sha256: "0".repeat(64),
    };
    const indexBody = jsonBody(mismatchedIndex);
    const manifest = validateManifest({
      ...fixtureManifest,
      session_index: {
        ...fixtureManifest.session_index,
        sha256: await sha256Hex(indexBody),
      },
    });
    fetchMock.mockResolvedValueOnce(new Response(indexBody));

    const error = await captureArtifactError(() =>
      loadSessionIndex(manifest),
    );

    expect(error.code).toBe("HASH_MISMATCH");
  });

  it("rejects a session artifact identifier that differs from its index", async () => {
    const mismatchedSession = {
      ...fixtureSession,
      provenance: {
        ...fixtureSession.provenance,
        artifact_sha256: "0".repeat(64),
      },
    };
    const sessionBody = jsonBody(mismatchedSession);
    const index = {
      ...fixtureSessionIndex,
      sessions: [
        {
          ...fixtureSessionIndex.sessions[0]!,
          sha256: await sha256Hex(sessionBody),
        },
      ],
    };
    const indexBody = jsonBody(index);
    const manifest = validateManifest({
      ...fixtureManifest,
      session_index: {
        ...fixtureManifest.session_index,
        sha256: await sha256Hex(indexBody),
      },
    });
    fetchMock
      .mockResolvedValueOnce(new Response(indexBody))
      .mockResolvedValueOnce(new Response(sessionBody));

    const validatedIndex = await loadSessionIndex(manifest);
    const error = await captureArtifactError(() =>
      loadSession(validatedIndex.sessions[0]!),
    );

    expect(error.code).toBe("HASH_MISMATCH");
  });

  it.each([
    {
      name: "session status",
      change(session: SessionArtifact): void {
        session.status = "HISTORICAL_OOS";
      },
    },
    {
      name: "dataset provenance",
      change(session: SessionArtifact): void {
        session.provenance.dataset_sha256 = "0".repeat(64);
      },
    },
    {
      name: "feature provenance",
      change(session: SessionArtifact): void {
        session.provenance.feature_version = "different-feature-version";
      },
    },
    {
      name: "model provenance",
      change(session: SessionArtifact): void {
        session.provenance.direction_model_version = "different-model-version";
      },
    },
    {
      name: "caveat provenance",
      change(session: SessionArtifact): void {
        session.provenance.caveat_codes = ["UI_FIXTURE"];
      },
    },
    {
      name: "session date identity",
      change(session: SessionArtifact): void {
        session.session_date = "2026-07-23";
      },
    },
  ])("rejects authenticated bytes with mismatched $name", async ({ change }) => {
    const invalid = structuredClone(fixtureSession) as SessionArtifact;
    change(invalid);

    const error = await loadMutatedAuthenticatedSession(invalid);

    expect(error.code).toBe("HASH_MISMATCH");
  });

  it("rejects an authenticated entry whose row count differs from its session", async () => {
    const error = await loadMutatedAuthenticatedSession(
      structuredClone(fixtureSession) as SessionArtifact,
      { entry: { rows: fixtureSession.rows.length + 1 } },
    );

    expect(error.code).toBe("HASH_MISMATCH");
  });
});
