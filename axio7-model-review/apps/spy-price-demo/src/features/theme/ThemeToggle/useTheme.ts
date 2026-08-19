import { useEffect, useState } from "react";

export type Theme = "light" | "dark";

const storageKey = "spy-demo-theme";

function readStoredTheme(): Theme {
  return window.localStorage.getItem(storageKey) === "dark" ? "dark" : "light";
}

function applyTheme(theme: Theme): void {
  document.documentElement.dataset.theme = theme;
  window.localStorage.setItem(storageKey, theme);
}

export interface ThemeState {
  theme: Theme;
  toggleTheme(): void;
}

export function useTheme(): ThemeState {
  const [theme, setTheme] = useState<Theme>(readStoredTheme);

  useEffect(() => {
    applyTheme(theme);
  }, [theme]);

  return {
    theme,
    toggleTheme: () => setTheme((currentTheme) => (currentTheme === "light" ? "dark" : "light")),
  };
}
