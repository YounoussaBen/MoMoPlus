export interface TableQueryInput {
  page: number;
  pageSize: number;
  search: string;
  activeFilters: Record<string, string>;
}

export type ApiQueryParamValue = string | number | boolean;
type QueryParamValue = ApiQueryParamValue | null | undefined;

export function compactQueryParams(
  params: Record<string, QueryParamValue>,
): Record<string, ApiQueryParamValue> {
  return Object.fromEntries(
    Object.entries(params).filter(
      ([, value]) => value !== undefined && value !== null && value !== "",
    ),
  ) as Record<string, ApiQueryParamValue>;
}

export function buildTableQueryParams(
  input: TableQueryInput,
  options?: {
    staticParams?: Record<string, QueryParamValue>;
    excludeFilterKeys?: string[];
  },
) {
  const excludeFilterKeys = new Set(options?.excludeFilterKeys ?? []);
  const filterParams = Object.fromEntries(
    Object.entries(input.activeFilters).filter(
      ([key, value]) => value && !excludeFilterKeys.has(key),
    ),
  );

  return compactQueryParams({
    ...(options?.staticParams ?? {}),
    page: input.page,
    page_size: input.pageSize,
    search: input.search || undefined,
    ...filterParams,
  });
}
