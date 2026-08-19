import type { JSX } from "react";
import styles from "./ThemeToggle.module.css";
import { useTheme } from "./useTheme";

export function ThemeToggle(): JSX.Element {
  const { theme, toggleTheme } = useTheme();
  const isDark = theme === "dark";

  return (
    <button
      type="button"
      className={styles.toggle}
      aria-label={isDark ? "Switch to light mode" : "Switch to dark mode"}
      onClick={toggleTheme}
    >
      {isDark ? "Light" : "Dark"}
    </button>
  );
}
