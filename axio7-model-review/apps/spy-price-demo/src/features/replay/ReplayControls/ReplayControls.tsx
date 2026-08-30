import type { JSX } from "react";
import styles from "./ReplayControls.module.css";

interface ReplayControlsProps {
  cutoffIndex: number;
  cutoffLabel: string;
  maximumCutoff: number;
  setCutoff(cutoffIndex: number): void;
}

export function ReplayControls({
  cutoffIndex,
  cutoffLabel,
  maximumCutoff,
  setCutoff,
}: ReplayControlsProps): JSX.Element {
  return (
    <div className={styles.fields}>
      <span className={styles.time}>{cutoffLabel}</span>
      <input
        className={styles.range}
        type="range"
        min={0}
        max={maximumCutoff}
        step={1}
        value={cutoffIndex}
        aria-label="Replay cutoff minute"
        onChange={(event) => setCutoff(Number(event.currentTarget.value))}
      />
    </div>
  );
}
