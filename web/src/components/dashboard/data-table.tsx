"use client";

import React, { useState, useRef } from "react";
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  FileText,
  Loader2,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export interface Column<T = any> {
  key: keyof T;
  label: string;
  width?: string;
  render?: (value: unknown, row: T, index?: number) => React.ReactNode;
  sortable?: boolean;
  hideOnMobile?: boolean;
  primaryOnMobile?: boolean;
  wrap?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
interface DataTableProps<T = any> {
  columns: Column<T>[];
  data: T[];
  isLoading?: boolean;
  onRowClick?: (row: T) => void;
  actions?: (row: T) => React.ReactNode;
  currentPage?: number;
  totalItems?: number;
  pageSize?: number;
  onPageChange?: (page: number) => void;
  onPageSizeChange?: (size: number) => void;
  emptyState?: {
    icon?: LucideIcon;
    title?: string;
    description?: string;
    action?: React.ReactNode;
  };
  loadingText?: string;
}

const PAGE_SIZE_PRESETS = [5, 10, 20, 50, 100];

function PageSizeControl({
  pageSize,
  onPageSizeChange,
}: {
  pageSize: number;
  onPageSizeChange: (size: number) => void;
}) {
  const isPreset = PAGE_SIZE_PRESETS.includes(pageSize);
  const [manualCustom, setManualCustom] = useState(false);
  const [customValue, setCustomValue] = useState(!isPreset ? String(pageSize) : "");
  const inputRef = useRef<HTMLInputElement>(null);

  // Show custom input only when user explicitly selected "Custom..." and value isn't a preset
  const isCustom = manualCustom && !isPreset;

  const handleSelectChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (e.target.value === "custom") {
      setManualCustom(true);
      setCustomValue("");
      setTimeout(() => inputRef.current?.focus(), 0);
    } else {
      setManualCustom(false);
      onPageSizeChange(Number(e.target.value));
    }
  };

  const commitCustom = () => {
    const val = parseInt(customValue, 10);
    if (val > 0) {
      onPageSizeChange(val);
    } else {
      setManualCustom(false);
      setCustomValue("");
    }
  };

  const controlClass =
    "py-2 rounded-xl border border-border bg-card text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/20 focus:border-ring transition-all duration-200";

  return (
    <div className="flex items-center gap-2">
      <span className="text-muted-foreground text-sm">Rows</span>
      {isCustom ? (
        <input
          ref={inputRef}
          type="number"
          min={1}
          value={customValue}
          onChange={(e) => setCustomValue(e.target.value)}
          onBlur={commitCustom}
          onKeyDown={(e) => {
            if (e.key === "Enter") commitCustom();
            if (e.key === "Escape") {
              setManualCustom(false);
              setCustomValue("");
            }
          }}
          className={`w-20 px-3 text-center ${controlClass}`}
        />
      ) : (
        <div className="relative">
          <select
            value={pageSize}
            onChange={handleSelectChange}
            className={`cursor-pointer appearance-none pr-8 pl-3 ${controlClass}`}
          >
            {PAGE_SIZE_PRESETS.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
            <option value="custom">Custom...</option>
          </select>
          <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2.5">
            <ChevronDown size={14} className="text-muted-foreground" />
          </div>
        </div>
      )}
    </div>
  );
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function DataTable<T = any>({
  columns,
  data,
  isLoading = false,
  onRowClick,
  actions,
  currentPage = 1,
  totalItems = 0,
  pageSize = 10,
  onPageChange,
  onPageSizeChange,
  emptyState,
  loadingText = "Loading...",
}: DataTableProps<T>) {
  const totalPages = Math.ceil(totalItems / pageSize);
  const EmptyIcon = emptyState?.icon ?? FileText;

  const rangeStart = totalItems === 0 ? 0 : (currentPage - 1) * pageSize + 1;
  const rangeEnd = Math.min(currentPage * pageSize, totalItems);

  const prevDisabled = currentPage <= 1 || totalPages <= 1;
  const nextDisabled = currentPage >= totalPages || totalPages <= 1;

  const showPaginationFooter = !!(onPageChange || onPageSizeChange);

  const PaginationFooter = (
    <div className="bg-card flex flex-col flex-wrap items-center justify-between gap-3 rounded-lg p-4 sm:flex-row">
      <p className="text-muted-foreground text-center text-sm sm:text-left">
        {totalItems === 0 ? "No results" : `${rangeStart}\u2013${rangeEnd} of ${totalItems}`}
      </p>

      <div className="flex flex-wrap items-center justify-center gap-3 sm:justify-end">
        {onPageSizeChange && (
          <PageSizeControl pageSize={pageSize} onPageSizeChange={onPageSizeChange} />
        )}

        {onPageChange && (
          <div className="flex items-center gap-1">
            <button
              onClick={() => onPageChange(1)}
              disabled={prevDisabled}
              className="hover:bg-muted rounded-lg p-2 transition-colors disabled:cursor-not-allowed disabled:opacity-50"
              title="First page"
            >
              <ChevronsLeft size={18} />
            </button>
            <button
              onClick={() => onPageChange(currentPage - 1)}
              disabled={prevDisabled}
              className="hover:bg-muted rounded-lg p-2 transition-colors disabled:cursor-not-allowed disabled:opacity-50"
              title="Previous page"
            >
              <ChevronLeft size={18} />
            </button>

            <div className="flex items-center gap-1">
              {Array.from({ length: totalPages }, (_, i) => i + 1)
                .filter((page) => {
                  if (totalPages <= 5) return true;
                  if (page === 1 || page === totalPages) return true;
                  if (Math.abs(page - currentPage) <= 1) return true;
                  return false;
                })
                .map((page, idx, arr) => (
                  <React.Fragment key={page}>
                    {idx > 0 && arr[idx - 1] !== page - 1 && (
                      <span className="text-muted-foreground px-1">...</span>
                    )}
                    <button
                      onClick={() => onPageChange(page)}
                      className={`rounded-lg border px-3 py-1 text-sm transition-colors ${
                        page === currentPage
                          ? "border-primary bg-primary text-primary-foreground"
                          : "border-border/50 hover:bg-muted"
                      }`}
                    >
                      {page}
                    </button>
                  </React.Fragment>
                ))}
            </div>

            <button
              onClick={() => onPageChange(currentPage + 1)}
              disabled={nextDisabled}
              className="hover:bg-muted rounded-lg p-2 transition-colors disabled:cursor-not-allowed disabled:opacity-50"
              title="Next page"
            >
              <ChevronRight size={18} />
            </button>
            <button
              onClick={() => onPageChange(totalPages)}
              disabled={nextDisabled}
              className="hover:bg-muted rounded-lg p-2 transition-colors disabled:cursor-not-allowed disabled:opacity-50"
              title="Last page"
            >
              <ChevronsRight size={18} />
            </button>
          </div>
        )}
      </div>
    </div>
  );

  if (isLoading) {
    return (
      <div className="bg-card flex h-64 w-full items-center justify-center rounded-xl">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="text-primary h-8 w-8 animate-spin" />
          <p className="text-muted-foreground text-sm">{loadingText}</p>
        </div>
      </div>
    );
  }

  if (data.length === 0) {
    return (
      <div className="w-full space-y-4">
        <div className="bg-card w-full rounded-xl p-8 text-center">
          <EmptyIcon className="text-muted-foreground mx-auto mb-4 h-12 w-12" />
          <h2 className="text-foreground mb-2 text-lg font-semibold">
            {emptyState?.title ?? "No data found"}
          </h2>
          <p className="text-muted-foreground mb-4">
            {emptyState?.description ?? "Try adjusting your filters or search criteria"}
          </p>
          {emptyState?.action && <div className="mt-4">{emptyState.action}</div>}
        </div>
        {showPaginationFooter && PaginationFooter}
      </div>
    );
  }

  const primaryColumn = columns.find((col) => col.primaryOnMobile) || columns[0];
  const secondaryColumns = columns.filter((col) => col !== primaryColumn && !col.hideOnMobile);

  return (
    <div className="w-full space-y-4">
      {/* Desktop Table */}
      <div className="border-border/50 bg-card hidden overflow-x-auto rounded-lg border md:block">
        <table className="w-full min-w-max">
          <thead>
            <tr className="border-border/50 bg-background/50 border-b">
              {columns.map((column) => (
                <th
                  key={String(column.key)}
                  className="text-muted-foreground px-4 py-3 text-left text-xs font-semibold tracking-wide whitespace-nowrap uppercase"
                  style={{ minWidth: column.width }}
                >
                  {column.label}
                </th>
              ))}
              {actions && (
                <th className="text-muted-foreground min-w-[80px] px-4 py-3 text-right text-xs font-semibold tracking-wide whitespace-nowrap uppercase">
                  Actions
                </th>
              )}
            </tr>
          </thead>
          <tbody>
            {data.map((row, index) => (
              <tr
                key={index}
                className={`border-border/30 border-b transition-colors last:border-0 ${
                  onRowClick ? "hover:bg-muted/40 cursor-pointer" : ""
                }`}
                onClick={() => onRowClick?.(row)}
              >
                {columns.map((column) => (
                  <td
                    key={String(column.key)}
                    className="text-foreground px-4 py-3.5 align-middle text-sm"
                    style={{
                      minWidth: column.width,
                      maxWidth: column.wrap ? column.width : undefined,
                    }}
                  >
                    <div className={column.wrap ? "break-words" : undefined}>
                      {column.render
                        ? column.render(row[column.key], row, index)
                        : String(row[column.key] ?? "")}
                    </div>
                  </td>
                ))}
                {actions && (
                  <td
                    className="min-w-[80px] px-4 py-3.5 text-right align-middle whitespace-nowrap"
                    onClick={(e) => e.stopPropagation()}
                  >
                    {actions(row)}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile Cards */}
      <div className="space-y-3 md:hidden">
        {data.map((row, index) => (
          <div
            key={index}
            className={`border-border/50 bg-card rounded-lg border p-4 transition-colors ${
              onRowClick ? "hover:bg-muted/40 cursor-pointer" : ""
            }`}
            onClick={() => onRowClick?.(row)}
          >
            <div className="mb-3 flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-muted-foreground mb-1 text-xs">{primaryColumn.label}</p>
                <div className="text-foreground text-sm font-medium">
                  {primaryColumn.render
                    ? primaryColumn.render(row[primaryColumn.key], row)
                    : String(row[primaryColumn.key] ?? "")}
                </div>
              </div>
              {actions && <div onClick={(e) => e.stopPropagation()}>{actions(row)}</div>}
            </div>
            <div className="grid grid-cols-2 gap-3">
              {secondaryColumns.map((column) => (
                <div key={String(column.key)} className="min-w-0">
                  <p className="text-muted-foreground mb-1 text-xs">{column.label}</p>
                  <div className="text-foreground text-sm">
                    {column.render
                      ? column.render(row[column.key], row)
                      : String(row[column.key] ?? "")}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Pagination Footer */}
      {showPaginationFooter && PaginationFooter}
    </div>
  );
}
