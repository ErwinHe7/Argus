import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { App } from "./App";

describe("App", () => {
  it("exposes a named SPY demo shell", () => {
    render(<App />);
    expect(screen.getByRole("main", { name: "SPY five-minute replay" })).toBeInTheDocument();
  });
});
