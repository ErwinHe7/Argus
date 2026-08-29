import { HttpBoundaryError } from "../retained-http/boundary.ts";
import { ScenarioConflictError } from "./ports.ts";

export function mapScenarioBoundaryError(
  error: unknown,
): HttpBoundaryError | undefined {
  if (!(error instanceof ScenarioConflictError)) return undefined;
  const invalid = error.code === "invalid_scenario_input" ||
    error.code === "invalid_scenario_horizon" ||
    error.code === "scenario_value_too_large";
  return new HttpBoundaryError(
    invalid ? 422 : 409,
    error.code,
    invalid
      ? "The reviewed hypothetical scenario assumptions are invalid."
      : "The idempotency key conflicts with an earlier reviewed request.",
  );
}
