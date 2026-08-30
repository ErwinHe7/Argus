import { HttpBoundaryError } from "../retained-http/boundary.ts";
import { StarpathError } from "./ports.ts";

export function mapStarpathBoundaryError(
  error: unknown,
): HttpBoundaryError | undefined {
  if (!(error instanceof StarpathError)) return undefined;
  switch (error.code) {
    case "starpath_unavailable":
    case "starpath_content_unavailable":
    case "starpath_replacement_unavailable":
      return new HttpBoundaryError(
        503,
        error.code,
        "Starpath is temporarily unavailable.",
        true,
      );
    case "starpath_session_not_found":
      return new HttpBoundaryError(
        404,
        error.code,
        "The requested Starpath session was not found.",
      );
    case "starpath_lifecycle_closed":
    case "starpath_idempotency_conflict":
    case "starpath_progress_conflict":
    case "starpath_session_conflict":
    case "starpath_node_locked":
    case "starpath_content_conflict":
    case "starpath_recall_conflict":
      return new HttpBoundaryError(
        409,
        error.code,
        "Starpath changed. Refresh before trying again.",
      );
  }
}
