import { HttpBoundaryError } from "../retained-http/boundary.ts";
import { BrokerageConnectionError } from "./service.ts";

export function mapBrokerageConnectionBoundaryError(
  error: unknown,
): HttpBoundaryError | undefined {
  if (!(error instanceof BrokerageConnectionError)) return undefined;
  const stepUp = error.code === "step_up_required";
  const conflict = error.code === "connection_already_connected";
  return new HttpBoundaryError(
    stepUp ? 403 : conflict ? 409 : 404,
    error.code,
    stepUp
      ? "A current action-bound authorization is required."
      : conflict
      ? "The Webull connection already exists."
      : "The requested brokerage resource was not found.",
  );
}
