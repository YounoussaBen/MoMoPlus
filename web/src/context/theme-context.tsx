"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  THEME_STORAGE_KEY,
  type ResolvedTheme,
  type ThemePreference,
  isThemePreference,
} from "@/lib/theme";

interface ThemeContextValue {
  theme: ThemePreference;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: ThemePreference) => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function getSystemTheme(): ResolvedTheme {
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function resolveTheme(theme: ThemePreference): ResolvedTheme {
  return theme === "system" ? getSystemTheme() : theme;
}

function applyTheme(theme: ThemePreference) {
  const resolvedTheme = resolveTheme(theme);
  const root = document.documentElement;

  root.dataset.themePreference = theme;
  root.dataset.theme = resolvedTheme;
  root.style.colorScheme = resolvedTheme;

  return resolvedTheme;
}

function getStoredTheme(): ThemePreference {
  if (typeof window === "undefined") return "system";
  try {
    const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
    return isThemePreference(stored) ? stored : "system";
  } catch {
    return "system";
  }
}

function getInitialThemePreference(): ThemePreference {
  if (typeof document === "undefined") return "system";
  const datasetTheme = document.documentElement.dataset.themePreference ?? null;
  return isThemePreference(datasetTheme) ? datasetTheme : getStoredTheme();
}

function getInitialResolvedTheme(): ResolvedTheme {
  if (typeof document === "undefined") return "light";
  const datasetTheme = document.documentElement.dataset.theme;
  return datasetTheme === "dark" ? "dark" : "light";
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemePreference>(getInitialThemePreference);
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>(getInitialResolvedTheme);
  const themeRef = useRef<ThemePreference>(getInitialThemePreference());

  const setTheme = useCallback((nextTheme: ThemePreference) => {
    themeRef.current = nextTheme;
    setThemeState(nextTheme);
    setResolvedTheme(applyTheme(nextTheme));
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
    } catch {
      // Ignore storage failures and keep the in-memory preference for this session.
    }
  }, []);

  useEffect(() => {
    themeRef.current = theme;
    applyTheme(themeRef.current);

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    const handleChange = () => {
      if (themeRef.current !== "system") return;
      setResolvedTheme(applyTheme("system"));
    };

    mediaQuery.addEventListener("change", handleChange);
    return () => mediaQuery.removeEventListener("change", handleChange);
  }, [theme]);

  const value = useMemo(
    () => ({
      theme,
      resolvedTheme,
      setTheme,
    }),
    [resolvedTheme, setTheme, theme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
