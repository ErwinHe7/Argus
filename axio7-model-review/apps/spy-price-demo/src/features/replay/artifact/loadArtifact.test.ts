import fixtureManifest from "../../../../public/fixtures/spy-demo/manifest.json";
import fixtureSession from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import fixtureSessionIndex from "../../../../public/fixtures/spy-demo/sessions/index.json";
import { ArtifactError } from "./ArtifactError";
import {
  loadManifest,
  loadSession,
  loadSessionIndex,
} from "./loadArtifact";
import { validateManifest } from "./validateArtifact";

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

  it("maps a missing session response to MISSING_SESSION", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse({}, 404));

    const error = await captureArtifactError(() =>
      loadSession(fixtureSessionIndex.sessions[0]!),
    );

    expect(error.code).toBe("MISSING_SESSION");
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
    fetchMock.mockResolvedValueOnce(
      new Response(`${jsonBody(fixtureSession)}\n `),
    );

    const error = await captureArtifactError(() =>
      loadSession(fixtureSessionIndex.sessions[0]!),
    );

    expect(error.code).toBe("HASH_MISMATCH");
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
});
