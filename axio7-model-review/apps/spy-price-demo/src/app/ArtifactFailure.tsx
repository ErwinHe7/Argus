import type { JSX } from "react";
import type { ArtifactError } from "../features/replay/artifact/ArtifactError";

export const artifactRemediationCommand =
  "python -m intraday_quant.demo.cli build --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output apps/spy-price-demo/public/generated";

interface ArtifactFailureProps {
  className?: string | undefined;
  error: ArtifactError;
}

export function ArtifactFailure({
  className,
  error,
}: ArtifactFailureProps): JSX.Element {
  return (
    <section className={className} aria-labelledby="artifact-failure-title">
      <h1 id="artifact-failure-title">Artifact failure</h1>
      <p>{error.message}</p>
      <code>{error.code}</code>
      <code>{artifactRemediationCommand}</code>
    </section>
  );
}
