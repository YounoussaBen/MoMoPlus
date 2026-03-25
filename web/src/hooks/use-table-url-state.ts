"use client";

import type { Route } from "next";
import { startTransition, useCallback, useEffect, useMemo, useRef } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  clearStoredTableState,
  readStoredTableState,
  useDashboardPreferences,
  writeStoredTableState,
} from "@/hooks/use-dashboard-preferences";

interface UseTableUrlStateOptions {
  defaultPageSize?: number;
  filterKeys?: string[];
}

function parsePositiveInt(value: string | null, fallback: number) {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function useTableUrlState({
  defaultPageSize,
  filterKeys = [],
}: UseTableUrlStateOptions = {}) {
  const { preferences } = useDashboardPreferences();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const hasRestoredStoredState = useRef(false);
  const resolvedDefaultPageSize = defaultPageSize ?? preferences.defaultTablePageSize;

  const page = parsePositiveInt(searchParams.get("page"), 1);
  const pageSize = parsePositiveInt(searchParams.get("page_size"), resolvedDefaultPageSize);
  const search = searchParams.get("search") ?? "";
  const activeFilters = useMemo(
    () =>
      Object.fromEntries(
        filterKeys.map((filterKey) => [filterKey, searchParams.get(filterKey) ?? ""]),
      ),
    [filterKeys, searchParams],
  );
  const hasExplicitTableState = useMemo(
    () =>
      !!searchParams.get("page") ||
      !!searchParams.get("page_size") ||
      !!searchParams.get("search") ||
      filterKeys.some((filterKey) => !!searchParams.get(filterKey)),
    [filterKeys, searchParams],
  );

  useEffect(() => {
    if (hasRestoredStoredState.current) return;

    if (!preferences.rememberListFilters || hasExplicitTableState) {
      hasRestoredStoredState.current = true;
      return;
    }

    const storedQuery = readStoredTableState(pathname);
    hasRestoredStoredState.current = true;
    if (!storedQuery) return;

    startTransition(() => {
      router.replace(`${pathname}?${storedQuery}` as Route, { scroll: false });
    });
  }, [hasExplicitTableState, pathname, preferences.rememberListFilters, router]);

  useEffect(() => {
    if (!preferences.rememberListFilters) {
      clearStoredTableState(pathname);
      return;
    }

    const trackedParams = new URLSearchParams();

    ["page", "page_size", "search"].forEach((key) => {
      const value = searchParams.get(key);
      if (value) trackedParams.set(key, value);
    });

    filterKeys.forEach((filterKey) => {
      const value = searchParams.get(filterKey);
      if (value) trackedParams.set(filterKey, value);
    });

    writeStoredTableState(pathname, trackedParams.toString());
  }, [filterKeys, pathname, preferences.rememberListFilters, searchParams]);

  const replaceParams = useCallback(
    (mutate: (params: URLSearchParams) => void) => {
      const nextParams = new URLSearchParams(searchParams.toString());
      mutate(nextParams);

      if (nextParams.get("page") === "1") nextParams.delete("page");
      if (nextParams.get("page_size") === String(resolvedDefaultPageSize)) {
        nextParams.delete("page_size");
      }
      if (!nextParams.get("search")) nextParams.delete("search");

      filterKeys.forEach((filterKey) => {
        if (!nextParams.get(filterKey)) nextParams.delete(filterKey);
      });

      const nextQuery = nextParams.toString();
      const currentQuery = searchParams.toString();
      const nextHref = nextQuery ? `${pathname}?${nextQuery}` : pathname;
      const currentHref = currentQuery ? `${pathname}?${currentQuery}` : pathname;

      if (nextHref === currentHref) return;

      startTransition(() => {
        router.replace(nextHref as Route, { scroll: false });
      });
    },
    [filterKeys, pathname, resolvedDefaultPageSize, router, searchParams],
  );

  const setPage = useCallback(
    (nextPage: number) => {
      replaceParams((params) => {
        params.set("page", String(nextPage));
      });
    },
    [replaceParams],
  );

  const setPageSize = useCallback(
    (nextPageSize: number) => {
      replaceParams((params) => {
        params.set("page_size", String(nextPageSize));
        params.set("page", "1");
      });
    },
    [replaceParams],
  );

  const setSearch = useCallback(
    (nextSearch: string) => {
      replaceParams((params) => {
        if (nextSearch) {
          params.set("search", nextSearch);
        } else {
          params.delete("search");
        }
        params.set("page", "1");
      });
    },
    [replaceParams],
  );

  const setFilter = useCallback(
    (key: string, value: string) => {
      replaceParams((params) => {
        if (value) {
          params.set(key, value);
        } else {
          params.delete(key);
        }
        params.set("page", "1");
      });
    },
    [replaceParams],
  );

  const clearFilters = useCallback(() => {
    replaceParams((params) => {
      params.delete("search");
      params.set("page", "1");
      filterKeys.forEach((filterKey) => params.delete(filterKey));
    });
  }, [filterKeys, replaceParams]);

  return {
    page,
    pageSize,
    search,
    activeFilters,
    setPage,
    setPageSize,
    setSearch,
    setFilter,
    clearFilters,
  };
}
