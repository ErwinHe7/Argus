import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import styles from "./ThemeToggle.module.css";
import { ThemeToggle } from "./ThemeToggle";

const localStorageDescriptor = Object.getOwnPropertyDescriptor(
  window,
  "localStorage",
);

function createMemoryStorage(): Storage {
  const values = new Map<string, string>();

  return {
    get length() {
      return values.size;
    },
    clear: () => values.clear(),
    getItem: (key) => values.get(key) ?? null,
    key: (index) => Array.from(values.keys())[index] ?? null,
    removeItem: (key) => values.delete(key),
    setItem: (key, value) => values.set(key, value),
  };
}

beforeEach(() => {
  Object.defineProperty(window, "localStorage", {
    configurable: true,
    value: createMemoryStorage(),
  });
});

afterEach(() => {
  if (localStorageDescriptor !== undefined) {
    Object.defineProperty(window, "localStorage", localStorageDescriptor);
  }
  delete document.documentElement.dataset.theme;
});

describe("ThemeToggle", () => {
  it("restores dark mode with a clear visible and accessible action", () => {
    window.localStorage.setItem("spy-demo-theme", "dark");

    render(<ThemeToggle />);

    expect(document.documentElement).toHaveAttribute("data-theme", "dark");
    expect(screen.getByRole("button", { name: "Switch to light mode" })).toHaveTextContent(
      "Light",
    );
  });

  it("stores light mode when toggled from dark mode", async () => {
    const user = userEvent.setup();
    window.localStorage.setItem("spy-demo-theme", "dark");
    render(<ThemeToggle />);

    await user.click(screen.getByRole("button", { name: "Switch to light mode" }));

    expect(document.documentElement).toHaveAttribute("data-theme", "light");
    expect(window.localStorage.getItem("spy-demo-theme")).toBe("light");
    expect(screen.getByRole("button", { name: "Switch to dark mode" })).toHaveTextContent(
      "Dark",
    );
  });

  it("uses no transition or animation class names", () => {
    expect(Object.values(styles).join(" ")).not.toMatch(/transition|animate/i);
  });
});
