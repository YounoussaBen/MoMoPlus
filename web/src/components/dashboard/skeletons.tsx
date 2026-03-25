import { Skeleton } from "@/components/ui/skeleton";

/** Skeleton for the FilterBar (search + filter dropdowns) */
export function FilterBarSkeleton({ filterCount = 2 }: { filterCount?: number }) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <Skeleton className="h-10 w-64 rounded-xl" />
      {Array.from({ length: filterCount }).map((_, i) => (
        <Skeleton key={i} className="h-10 w-28 rounded-xl" />
      ))}
    </div>
  );
}

/** Skeleton for a DataTable with header + rows */
export function TableSkeleton({
  columns = 5,
  rows = 8,
  hasActions = true,
}: {
  columns?: number;
  rows?: number;
  hasActions?: boolean;
}) {
  const totalCols = hasActions ? columns + 1 : columns;

  return (
    <div className="border-border/50 bg-card overflow-hidden rounded-lg border">
      {/* Header */}
      <div className="border-border/50 bg-background/50 border-b px-4 py-3">
        <div className="flex gap-4">
          {Array.from({ length: totalCols }).map((_, i) => (
            <Skeleton
              key={i}
              className="h-3 rounded"
              style={{ width: i === 0 ? "15%" : i === totalCols - 1 ? "8%" : "12%" }}
            />
          ))}
        </div>
      </div>
      {/* Rows */}
      {Array.from({ length: rows }).map((_, rowIdx) => (
        <div
          key={rowIdx}
          className="border-border/30 flex items-center gap-4 border-b px-4 py-3.5 last:border-0"
        >
          {Array.from({ length: totalCols }).map((_, colIdx) => (
            <Skeleton
              key={colIdx}
              className="h-4 rounded"
              style={{
                width:
                  colIdx === 0
                    ? "15%"
                    : colIdx === 1
                      ? "20%"
                      : colIdx === totalCols - 1
                        ? "8%"
                        : "12%",
              }}
            />
          ))}
        </div>
      ))}
      {/* Pagination footer */}
      <div className="border-border/50 flex items-center justify-between border-t px-4 py-3">
        <Skeleton className="h-4 w-32 rounded" />
        <div className="flex gap-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-8 w-8 rounded-lg" />
          ))}
        </div>
      </div>
    </div>
  );
}

/** Full page skeleton for list pages (filter bar + table) */
export function TablePageSkeleton({
  title,
  subtitle,
  columns = 5,
  rows = 8,
  filterCount = 2,
}: {
  title: string;
  subtitle: string;
  columns?: number;
  rows?: number;
  filterCount?: number;
}) {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">{title}</h1>
        <p className="text-muted-foreground text-sm">{subtitle}</p>
      </div>
      <FilterBarSkeleton filterCount={filterCount} />
      <TableSkeleton columns={columns} rows={rows} />
    </div>
  );
}

/** Skeleton for the detail page header (back button + name + badges) */
export function DetailHeaderSkeleton() {
  return (
    <div className="flex items-center gap-4">
      <Skeleton className="h-10 w-10 rounded-lg" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-7 w-48 rounded" />
        <Skeleton className="h-4 w-36 rounded" />
      </div>
      <div className="flex gap-2">
        <Skeleton className="h-6 w-16 rounded-full" />
        <Skeleton className="h-6 w-16 rounded-full" />
      </div>
    </div>
  );
}

/** Skeleton for a Section card (icon + title + rows of info) */
export function SectionSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="border-border/50 bg-card rounded-xl border">
      <div className="border-border/50 flex items-center gap-3 border-b px-6 py-4">
        <Skeleton className="h-5 w-5 rounded" />
        <Skeleton className="h-5 w-40 rounded" />
      </div>
      <div className="grid gap-4 px-6 py-5 sm:grid-cols-2">
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i} className="flex items-center gap-4">
            <Skeleton className="h-4 w-24 rounded" />
            <Skeleton className="h-4 w-32 rounded" />
          </div>
        ))}
      </div>
    </div>
  );
}

/** Skeleton for document grid (used in KYC and certification details) */
export function DocGridSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="border-border/50 bg-card rounded-xl border">
      <div className="border-border/50 flex items-center gap-3 border-b px-6 py-4">
        <Skeleton className="h-5 w-5 rounded" />
        <Skeleton className="h-5 w-36 rounded" />
        <Skeleton className="ml-1 h-5 w-16 rounded-full" />
      </div>
      <div className="space-y-5 px-6 py-5">
        <div className="grid gap-4 sm:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="flex items-center gap-4">
              <Skeleton className="h-4 w-24 rounded" />
              <Skeleton className="h-4 w-28 rounded" />
            </div>
          ))}
        </div>
        <div>
          <Skeleton className="mb-3 h-4 w-24 rounded" />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {Array.from({ length: count }).map((_, i) => (
              <Skeleton key={i} className="h-32 rounded-xl" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/** Full detail page skeleton — profile only */
export function UserDetailSkeleton() {
  return (
    <div className="space-y-6">
      <DetailHeaderSkeleton />
      <SectionSkeleton rows={4} />
    </div>
  );
}

/** Full detail page skeleton — profile + certification */
export function AgentDetailSkeleton() {
  return (
    <div className="space-y-6">
      <DetailHeaderSkeleton />
      <SectionSkeleton rows={4} />
      <DocGridSkeleton count={2} />
    </div>
  );
}

/** Full detail page skeleton — profile + KYC documents */
export function KycDetailSkeleton() {
  return (
    <div className="space-y-6">
      <DetailHeaderSkeleton />
      <SectionSkeleton rows={4} />
      <DocGridSkeleton count={4} />
    </div>
  );
}

/** Full dashboard shell skeleton (sidebar + header + content area) */
export function DashboardShellSkeleton() {
  return (
    <div className="flex min-h-screen">
      {/* Sidebar */}
      <div className="bg-card border-border/50 hidden w-64 flex-col border-r px-4 py-6 lg:flex">
        <Skeleton className="mb-8 h-10 w-32 rounded-xl" />
        <div className="space-y-2">
          {Array.from({ length: 7 }).map((_, i) => (
            <Skeleton key={i} className="h-10 w-full rounded-xl" />
          ))}
        </div>
        <div className="mt-auto">
          <Skeleton className="h-10 w-full rounded-xl" />
        </div>
      </div>
      {/* Main area */}
      <div className="flex min-w-0 flex-1 flex-col p-4 md:p-6">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Skeleton className="h-10 w-10 rounded-lg lg:hidden" />
            <div className="space-y-1.5">
              <Skeleton className="h-5 w-40 rounded" />
              <Skeleton className="h-3 w-28 rounded" />
            </div>
          </div>
          <Skeleton className="h-10 w-10 rounded-full" />
        </div>
        {/* Content */}
        <div className="space-y-6">
          <div className="space-y-2">
            <Skeleton className="h-7 w-48 rounded" />
            <Skeleton className="h-4 w-64 rounded" />
          </div>
          <TableSkeleton columns={5} rows={6} />
        </div>
      </div>
    </div>
  );
}
