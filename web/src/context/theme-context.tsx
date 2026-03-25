"use client";

import { createContext, useCallback, useContext, useMemo, useSyncExternalStore } from "react";
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
const DEFAULT_THEME: ThemePreference = "system";
const DEFAULT_RESOLVED_THEME: ResolvedTheme = "light";
const themeSubscribers = new Set<() => void>();

let cleanupThemeSubscriptions: (() => void) | null = null;

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
  if (typeof window === "undefined") return DEFAULT_THEME;
  try {
    const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
    return isThemePreference(stored) ? stored : DEFAULT_THEME;
  } catch {
    return DEFAULT_THEME;
  }
}

function getThemeSnapshot(): ThemePreference {
  if (typeof document === "undefined") return DEFAULT_THEME;
  const datasetTheme = document.documentElement.dataset.themePreference ?? null;
  return isThemePreference(datasetTheme) ? datasetTheme : getStoredTheme();
}

function getResolvedThemeSnapshot(): ResolvedTheme {
  if (typeof document === "undefined") return DEFAULT_RESOLVED_THEME;
  const datasetTheme = document.documentElement.dataset.theme;
  if (datasetTheme === "dark" || datasetTheme === "light") return datasetTheme;
  return resolveTheme(getThemeSnapshot());
}

function notifyThemeSubscribers() {
  themeSubscribers.forEach((subscriber) => subscriber());
}

function ensureThemeSubscriptions() {
  if (cleanupThemeSubscriptions || typeof window === "undefined") return;

  const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");

  const handleSystemThemeChange = () => {
    if (getThemeSnapshot() !== "system") return;
    applyTheme("system");
    notifyThemeSubscribers();
  };

  const handleStorageChange = (event: StorageEvent) => {
    if (event.key !== THEME_STORAGE_KEY) return;
    applyTheme(getStoredTheme());
    notifyThemeSubscribers();
  };

  mediaQuery.addEventListener("change", handleSystemThemeChange);
  window.addEventListener("storage", handleStorageChange);

  cleanupThemeSubscriptions = () => {
    mediaQuery.removeEventListener("change", handleSystemThemeChange);
    window.removeEventListener("storage", handleStorageChange);
  };
}

function subscribeToThemeStore(callback: () => void) {
  themeSubscribers.add(callback);
  ensureThemeSubscriptions();

  return () => {
    themeSubscribers.delete(callback);

    if (themeSubscribers.size === 0 && cleanupThemeSubscriptions) {
      cleanupThemeSubscriptions();
      cleanupThemeSubscriptions = null;
    }
  };
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const theme = useSyncExternalStore(subscribeToThemeStore, getThemeSnapshot, () => DEFAULT_THEME);
  const resolvedTheme = useSyncExternalStore(
    subscribeToThemeStore,
    getResolvedThemeSnapshot,
    () => DEFAULT_RESOLVED_THEME,
  );

  const setTheme = useCallback((nextTheme: ThemePreference) => {
    applyTheme(nextTheme);
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
    } catch {
      // Ignore storage failures and keep the in-memory preference for this session.
    }
    notifyThemeSubscribers();
  }, []);

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
