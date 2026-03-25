"use client";

import { useCallback, useSyncExternalStore } from "react";

export const DASHBOARD_RANGE_OPTIONS = [7, 14, 30, 90] as const;
export type DashboardRangeDays = (typeof DASHBOARD_RANGE_OPTIONS)[number];

export interface DashboardPreferences {
  defaultRangeDays: DashboardRangeDays;
  defaultTablePageSize: number;
  rememberListFilters: boolean;
}

export const DASHBOARD_PREFERENCES_STORAGE_KEY = "momoplus-admin-dashboard-preferences";
const TABLE_STATE_STORAGE_KEY_PREFIX = "momoplus-admin-table-state";

export const DEFAULT_DASHBOARD_PREFERENCES: DashboardPreferences = {
  defaultRangeDays: 30,
  defaultTablePageSize: 20,
  rememberListFilters: true,
};

const subscribers = new Set<() => void>();
let cleanupStorageListener: (() => void) | null = null;
let cachedPreferencesRaw: string | null | undefined;
let cachedPreferencesSnapshot = DEFAULT_DASHBOARD_PREFERENCES;

function normalizeRangeDays(value: unknown): DashboardRangeDays {
  const parsed = typeof value === "number" ? value : Number.parseInt(String(value ?? ""), 10);
  return DASHBOARD_RANGE_OPTIONS.includes(parsed as DashboardRangeDays)
    ? (parsed as DashboardRangeDays)
    : DEFAULT_DASHBOARD_PREFERENCES.defaultRangeDays;
}

function normalizePageSize(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed > 0 && parsed <= 200
    ? parsed
    : DEFAULT_DASHBOARD_PREFERENCES.defaultTablePageSize;
}

function normalizePreferences(value: unknown): DashboardPreferences {
  if (!value || typeof value !== "object") return DEFAULT_DASHBOARD_PREFERENCES;

  const record = value as Record<string, unknown>;

  return {
    defaultRangeDays: normalizeRangeDays(record.defaultRangeDays),
    defaultTablePageSize: normalizePageSize(record.defaultTablePageSize),
    rememberListFilters:
      typeof record.rememberListFilters === "boolean"
        ? record.rememberListFilters
        : DEFAULT_DASHBOARD_PREFERENCES.rememberListFilters,
  };
}

function notifySubscribers() {
  subscribers.forEach((subscriber) => subscriber());
}

function ensureStorageListener() {
  if (cleanupStorageListener || typeof window === "undefined") return;

  const handleStorage = (event: StorageEvent) => {
    if (event.key !== DASHBOARD_PREFERENCES_STORAGE_KEY) {
      return;
    }

    notifySubscribers();
  };

  window.addEventListener("storage", handleStorage);
  cleanupStorageListener = () => window.removeEventListener("storage", handleStorage);
}

function subscribe(callback: () => void) {
  subscribers.add(callback);
  ensureStorageListener();

  return () => {
    subscribers.delete(callback);

    if (subscribers.size === 0 && cleanupStorageListener) {
      cleanupStorageListener();
      cleanupStorageListener = null;
    }
  };
}

function readPreferencesSnapshot() {
  if (typeof window === "undefined") return DEFAULT_DASHBOARD_PREFERENCES;

  try {
    const raw = window.localStorage.getItem(DASHBOARD_PREFERENCES_STORAGE_KEY);
    if (raw === cachedPreferencesRaw) {
      return cachedPreferencesSnapshot;
    }

    cachedPreferencesRaw = raw;

    if (!raw) {
      cachedPreferencesSnapshot = DEFAULT_DASHBOARD_PREFERENCES;
      return cachedPreferencesSnapshot;
    }

    cachedPreferencesSnapshot = normalizePreferences(JSON.parse(raw));
    return cachedPreferencesSnapshot;
  } catch {
    cachedPreferencesRaw = null;
    cachedPreferencesSnapshot = DEFAULT_DASHBOARD_PREFERENCES;
    return cachedPreferencesSnapshot;
  }
}

export function buildStoredTableStateKey(pathname: string) {
  return `${TABLE_STATE_STORAGE_KEY_PREFIX}:${pathname}`;
}

export function readStoredTableState(pathname: string) {
  if (typeof window === "undefined") return "";

  try {
    return window.localStorage.getItem(buildStoredTableStateKey(pathname)) ?? "";
  } catch {
    return "";
  }
}

export function writeStoredTableState(pathname: string, query: string) {
  if (typeof window === "undefined") return;

  const storageKey = buildStoredTableStateKey(pathname);
  try {
    const previousValue = window.localStorage.getItem(storageKey) ?? "";
    if (previousValue === query) return;

    if (query) {
      window.localStorage.setItem(storageKey, query);
    } else {
      window.localStorage.removeItem(storageKey);
    }
  } catch {
    return;
  }
}

export function clearStoredTableState(pathname: string) {
  writeStoredTableState(pathname, "");
}

export function useDashboardPreferences() {
  const preferences = useSyncExternalStore(
    subscribe,
    readPreferencesSnapshot,
    () => DEFAULT_DASHBOARD_PREFERENCES,
  );

  const updatePreferences = useCallback((updates: Partial<DashboardPreferences>) => {
    if (typeof window === "undefined") return;

    const nextPreferences = normalizePreferences({
      ...readPreferencesSnapshot(),
      ...updates,
    });

    try {
      window.localStorage.setItem(
        DASHBOARD_PREFERENCES_STORAGE_KEY,
        JSON.stringify(nextPreferences),
      );
    } catch {
      return;
    }

    notifySubscribers();
  }, []);

  const resetPreferences = useCallback(() => {
    if (typeof window === "undefined") return;

    try {
      window.localStorage.removeItem(DASHBOARD_PREFERENCES_STORAGE_KEY);
    } catch {
      return;
    }

    notifySubscribers();
  }, []);

  return {
    preferences,
    updatePreferences,
    resetPreferences,
  };
}
