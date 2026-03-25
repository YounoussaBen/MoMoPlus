"use client";

import type { Route } from "next";
import { startTransition, useCallback, useMemo } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

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
  defaultPageSize = 20,
  filterKeys = [],
}: UseTableUrlStateOptions = {}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const page = parsePositiveInt(searchParams.get("page"), 1);
  const pageSize = parsePositiveInt(searchParams.get("page_size"), defaultPageSize);
  const search = searchParams.get("search") ?? "";
  const activeFilters = useMemo(
    () =>
      Object.fromEntries(
        filterKeys.map((filterKey) => [filterKey, searchParams.get(filterKey) ?? ""]),
      ),
    [filterKeys, searchParams],
  );

  const replaceParams = useCallback(
    (mutate: (params: URLSearchParams) => void) => {
      const nextParams = new URLSearchParams(searchParams.toString());
      mutate(nextParams);

      if (nextParams.get("page") === "1") nextParams.delete("page");
      if (nextParams.get("page_size") === String(defaultPageSize)) nextParams.delete("page_size");
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
    [defaultPageSize, filterKeys, pathname, router, searchParams],
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
