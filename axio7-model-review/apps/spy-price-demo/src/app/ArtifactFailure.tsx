import type { JSX } from "react";
import type { ArtifactError } from "../features/replay/artifact/ArtifactError";

export const artifactRemediationCommand =
  "python -m intraday_quant.demo.cli build --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output apps/spy-price-demo/public/generated";

interface ArtifactFailureProps {
  className?: string | undefined;
  error: ArtifactError;
}

function sanitizedArtifactPath(error: ArtifactError): string | undefined {
  if (
    error.path === "manifest.json" ||
    error.path === "sessions/index.json" ||
    /^sessions\/\d{4}-\d{2}-\d{2}\.json$/.test(error.path ?? "")
  ) {
    return error.path;
  }
  return undefined;
}

export function ArtifactFailure({
  className,
  error,
}: ArtifactFailureProps): JSX.Element {
  const artifactPath = sanitizedArtifactPath(error);
  return (
    <section className={className} aria-labelledby="artifact-failure-title">
      <h1 id="artifact-failure-title">Artifact failure</h1>
      <p>{error.message}</p>
      <code>{error.code}</code>
      {artifactPath === undefined ? null : (
        <code aria-label="Artifact path">{artifactPath}</code>
      )}
      <code>{artifactRemediationCommand}</code>
    </section>
  );
}
