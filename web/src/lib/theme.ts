export const THEME_STORAGE_KEY = "momoplus-admin-theme";

export type ThemePreference = "light" | "dark" | "system";
export type ResolvedTheme = Exclude<ThemePreference, "system">;

export function isThemePreference(value: string | null): value is ThemePreference {
  return value === "light" || value === "dark" || value === "system";
}

export const themeInitScript = `
(() => {
  const storageKey = "${THEME_STORAGE_KEY}";
  const root = document.documentElement;

  const getStoredTheme = () => {
    try {
      const stored = window.localStorage.getItem(storageKey);
      return stored === "light" || stored === "dark" || stored === "system" ? stored : "system";
    } catch {
      return "system";
    }
  };

  const getSystemTheme = () =>
    window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

  const theme = getStoredTheme();
  const resolvedTheme = theme === "system" ? getSystemTheme() : theme;

  root.dataset.themePreference = theme;
  root.dataset.theme = resolvedTheme;
  root.style.colorScheme = resolvedTheme;
})();
`;
