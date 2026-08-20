import type { JSX } from "react";

interface OutcomeRevealProps {
  className?: string | undefined;
  revealed: boolean;
  reveal(): void;
}

export function OutcomeReveal({
  className,
  revealed,
  reveal,
}: OutcomeRevealProps): JSX.Element {
  return (
    <button
      className={className}
      type="button"
      disabled={revealed}
      onClick={reveal}
    >
      {revealed ? "Revealed" : "Reveal +5m"}
    </button>
  );
}
