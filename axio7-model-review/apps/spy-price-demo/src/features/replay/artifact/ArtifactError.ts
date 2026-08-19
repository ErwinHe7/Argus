export type ArtifactErrorCode =
  | "NETWORK"
  | "INVALID_SCHEMA"
  | "UNSUPPORTED_VERSION"
  | "HASH_MISMATCH"
  | "MISSING_SESSION";

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

  static fromResponse(path: string, status: number): ArtifactError {
    if (status === 404) {
      return new ArtifactError(
        "MISSING_SESSION",
        "A requested artifact is unavailable.",
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
