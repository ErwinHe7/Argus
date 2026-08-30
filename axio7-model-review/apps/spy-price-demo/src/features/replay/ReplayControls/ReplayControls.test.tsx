import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ReplayControls } from "./ReplayControls";

describe("ReplayControls", () => {
  it("snaps the native minute range on input with a one-row step", () => {
    const setCutoff = vi.fn();
    render(
      <ReplayControls
        cutoffIndex={2}
        cutoffLabel="Cutoff 10:32 ET"
        maximumCutoff={6}
        setCutoff={setCutoff}
      />,
    );

    const slider = screen.getByRole("slider", { name: "Replay cutoff minute" });
    expect(slider).toHaveAttribute("min", "0");
    expect(slider).toHaveAttribute("max", "6");
    expect(slider).toHaveAttribute("step", "1");

    fireEvent.input(slider, { target: { value: "4" } });

    expect(setCutoff).toHaveBeenCalledOnce();
    expect(setCutoff).toHaveBeenCalledWith(4);
  });
});
