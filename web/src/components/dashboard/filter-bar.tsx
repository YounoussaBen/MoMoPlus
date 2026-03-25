"use client";

import { Search, X, ChevronDown } from "lucide-react";
import React from "react";

export interface FilterOption {
  label: string;
  value: string;
}

export interface FilterDefinition {
  label: string;
  key: string;
  options: FilterOption[];
}

export interface FilterBarProps {
  onSearch?: (query: string) => void;
  searchValue?: string;
  searchPlaceholder?: string;
  filters?: FilterDefinition[];
  onFilterChange?: (key: string, value: string) => void;
  onClearFilters?: () => void;
  activeFilters?: Record<string, string>;
  actions?: React.ReactNode;
}

export function FilterBar({
  onSearch,
  searchValue = "",
  searchPlaceholder = "Search here...",
  filters,
  onFilterChange,
  onClearFilters,
  activeFilters = {},
  actions,
}: FilterBarProps) {
  const hasActiveFilters = Object.values(activeFilters).some((v) => v) || searchValue.length > 0;

  return (
    <div className="bg-card space-y-3 rounded-xl p-4">
      {/* Search */}
      <div className="relative">
        <Search className="text-muted-foreground absolute top-1/2 left-3 size-4 -translate-y-1/2" />
        <input
          type="text"
          placeholder={searchPlaceholder}
          value={searchValue}
          onChange={(e) => onSearch?.(e.target.value)}
          className="border-border bg-background text-foreground placeholder:text-muted-foreground focus:border-ring focus:ring-ring/20 w-full rounded-xl border py-2.5 pr-4 pl-10 text-sm transition-all duration-200 focus:ring-2 focus:outline-none"
        />
      </div>

      {/* Filters + Actions row */}
      {((filters && filters.length > 0) || actions) && (
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-3">
            {filters?.map((filter) => (
              <div key={filter.key} className="relative">
                <select
                  value={activeFilters[filter.key] || ""}
                  onChange={(e) => onFilterChange?.(filter.key, e.target.value)}
                  className={`bg-background text-foreground focus:ring-ring/20 min-w-[160px] cursor-pointer appearance-none rounded-xl border py-2.5 pr-10 pl-4 text-sm transition-all duration-200 focus:ring-2 focus:outline-none ${
                    activeFilters[filter.key] ? "border-ring" : "border-border"
                  }`}
                >
                  <option value="">{filter.label}</option>
                  {filter.options.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
                  <ChevronDown className="text-muted-foreground h-4 w-4" />
                </div>
              </div>
            ))}

            {hasActiveFilters && onClearFilters && (
              <button
                onClick={() => {
                  onSearch?.("");
                  onClearFilters();
                }}
                className="border-border bg-background text-muted-foreground hover:border-ring hover:text-foreground flex items-center gap-2 rounded-xl border px-3 py-2.5 text-sm transition-all duration-200"
              >
                <X size={14} />
                Clear
              </button>
            )}
          </div>

          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </div>
      )}
    </div>
  );
}
