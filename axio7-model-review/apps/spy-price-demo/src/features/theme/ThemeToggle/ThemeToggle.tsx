import type { JSX } from "react";
import styles from "./ThemeToggle.module.css";
import { useTheme, type Theme } from "./useTheme";

interface ThemeToggleButtonProps {
  theme: Theme;
  toggleTheme(): void;
}

function ThemeToggleButton({
  theme,
  toggleTheme,
}: ThemeToggleButtonProps): JSX.Element {
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

function UncontrolledThemeToggle(): JSX.Element {
  return <ThemeToggleButton {...useTheme()} />;
}

export function ThemeToggle(props: Partial<ThemeToggleButtonProps>): JSX.Element {
  if (props.theme !== undefined && props.toggleTheme !== undefined) {
    return (
      <ThemeToggleButton theme={props.theme} toggleTheme={props.toggleTheme} />
    );
  }
  return <UncontrolledThemeToggle />;
}
