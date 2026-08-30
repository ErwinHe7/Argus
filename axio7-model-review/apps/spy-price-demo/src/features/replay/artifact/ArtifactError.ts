export type ArtifactErrorCode =
  | "NETWORK"
  | "INVALID_SCHEMA"
  | "UNSUPPORTED_VERSION"
  | "HASH_MISMATCH"
  | "MISSING_MANIFEST"
  | "MISSING_SESSION_INDEX"
  | "MISSING_SESSION";

export type ArtifactKind = "manifest" | "session index" | "session";

export class ArtifactError extends Error {
  readonly code: ArtifactErrorCode;
  readonly details: unknown;
  readonly path: string | undefined;

  constructor(
    code: ArtifactErrorCode,
    message: string,
    options: { cause?: unknown; details?: unknown; path?: string } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = "ArtifactError";
    this.code = code;
    this.details = options.details;
    this.path = options.path;
  }

  static invalidSchema(artifact: string, details?: unknown): ArtifactError {
    return new ArtifactError(
      "INVALID_SCHEMA",
      `The ${artifact} artifact is invalid.`,
      { details },
    );
  }

  static invalidJson(path: string, cause: unknown): ArtifactError {
    return new ArtifactError(
      "INVALID_SCHEMA",
      "An artifact response could not be decoded.",
      { cause, path },
    );
  }

  static unsupportedVersion(artifact: string, details?: unknown): ArtifactError {
    return new ArtifactError(
      "UNSUPPORTED_VERSION",
      `The ${artifact} artifact uses an unsupported contract version.`,
      { details },
    );
  }

  static hashMismatch(path: string, details?: unknown): ArtifactError {
    return new ArtifactError(
      "HASH_MISMATCH",
      "Artifact integrity verification failed.",
      { details, path },
    );
  }

  static fromResponse(
    path: string,
    status: number,
    artifactKind: ArtifactKind,
  ): ArtifactError {
    if (status === 404) {
      const missing = {
        manifest: {
          code: "MISSING_MANIFEST" as const,
          message: "The manifest artifact is unavailable.",
        },
        "session index": {
          code: "MISSING_SESSION_INDEX" as const,
          message: "The session index artifact is unavailable.",
        },
        session: {
          code: "MISSING_SESSION" as const,
          message: "The requested session artifact is unavailable.",
        },
      } satisfies Record<ArtifactKind, { code: ArtifactErrorCode; message: string }>;
      const classification = missing[artifactKind];
      return new ArtifactError(
        classification.code,
        classification.message,
        { details: { status }, path },
      );
    }

    return new ArtifactError(
      "NETWORK",
      "An artifact request failed.",
      { details: { status }, path },
    );
  }

  static network(path: string, cause: unknown): ArtifactError {
    return new ArtifactError(
      "NETWORK",
      "An artifact request failed.",
      { cause, path },
    );
  }
}
