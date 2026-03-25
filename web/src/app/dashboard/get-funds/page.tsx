"use client";

import { useCallback, useMemo } from "react";
import { useRouter } from "next/navigation";
import { Eye, Wallet } from "lucide-react";
import { useGetFundsList } from "@/hooks/use-get-funds";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import { formatCurrency, formatDate, formatLoanStatus, formatNetwork } from "@/lib/format";
import type { StaffLoanListItem } from "@/lib/types";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu, type TableActionItem } from "@/components/dashboard/table-action-menu";
import { Badge } from "@/components/ui/badge";

const filters: FilterDefinition[] = [
  {
    label: "Status",
    key: "status",
    options: [
      { label: "Pending", value: "pending" },
      { label: "Approved", value: "approved" },
      { label: "Disbursing", value: "disbursing" },
      { label: "Active", value: "active" },
      { label: "Repaying", value: "repaying" },
      { label: "Completed", value: "completed" },
      { label: "Defaulted", value: "defaulted" },
      { label: "Rejected", value: "rejected" },
      { label: "Cancelled", value: "cancelled" },
      { label: "Failed", value: "failed" },
    ],
  },
  {
    label: "Network",
    key: "network",
    options: [
      { label: "MTN", value: "mtn" },
      { label: "Telecel", value: "vodafone" },
      { label: "AirtelTigo", value: "airteltigo" },
    ],
  },
  {
    label: "Overdue",
    key: "is_overdue",
    options: [
      { label: "Overdue", value: "true" },
      { label: "Not overdue", value: "false" },
    ],
  },
];

const STATUS_VARIANT: Record<string, "muted" | "warning" | "info" | "success" | "destructive"> = {
  pending: "warning",
  approved: "info",
  disbursing: "info",
  active: "success",
  repaying: "warning",
  completed: "success",
  defaulted: "destructive",
  rejected: "destructive",
  cancelled: "muted",
  failed: "destructive",
};

const columns: Column<StaffLoanListItem>[] = [
  {
    key: "borrower_name",
    label: "Customer",
    primaryOnMobile: true,
    render: (_, row) => (
      <div>
        <p className="font-medium">{row.borrower_name || "—"}</p>
        <p className="text-muted-foreground text-xs">{row.borrower_email}</p>
      </div>
    ),
  },
  {
    key: "agent_name",
    label: "Agent",
    render: (_, row) => (
      <div>
        <p className="font-medium">{row.agent_name || "—"}</p>
        <p className="text-muted-foreground text-xs">{row.agent_email}</p>
      </div>
    ),
  },
  {
    key: "status",
    label: "Status",
    render: (_, row) => (
      <div className="flex flex-wrap items-center gap-2">
        <Badge variant={STATUS_VARIANT[row.status] ?? "muted"}>
          {formatLoanStatus(row.status)}
        </Badge>
        {row.is_overdue ? <Badge variant="destructive">Overdue</Badge> : null}
      </div>
    ),
  },
  {
    key: "outstanding_balance",
    label: "Outstanding",
    render: (_, row) => (
      <div>
        <p className="font-medium">{formatCurrency(row.outstanding_balance)}</p>
        <p className="text-muted-foreground text-xs">{formatNetwork(row.network)}</p>
      </div>
    ),
  },
  {
    key: "deadline_at",
    label: "Deadline",
    hideOnMobile: true,
    render: (_, row) => (row.deadline_at ? formatDate(row.deadline_at) : "—"),
  },
  {
    key: "created_at",
    label: "Created",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

const FILTER_KEYS = filters.map((filter) => filter.key);

export default function GetFundsPage() {
  const router = useRouter();
  const {
    page,
    pageSize,
    search,
    activeFilters,
    setPage,
    setPageSize,
    setSearch,
    setFilter,
    clearFilters,
  } = useTableUrlState({
    filterKeys: FILTER_KEYS,
  });

  const queryInput = useMemo(
    () => ({
      page,
      pageSize,
      search,
      activeFilters,
    }),
    [activeFilters, page, pageSize, search],
  );

  const getFundsQuery = useGetFundsList(queryInput);
  const data = getFundsQuery.data?.results ?? [];
  const totalItems = getFundsQuery.data?.count ?? 0;

  const handleSearch = useCallback((query: string) => setSearch(query), [setSearch]);
  const handleFilterChange = useCallback(
    (key: string, value: string) => setFilter(key, value),
    [setFilter],
  );
  const handleClearFilters = useCallback(() => clearFilters(), [clearFilters]);
  const handlePageSizeChange = useCallback((size: number) => setPageSize(size), [setPageSize]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">Get Funds</h1>
        <p className="text-muted-foreground text-sm">
          Monitor active cases, track disbursements and repayments, and watch overdue balances.
        </p>
      </div>

      <FilterBar
        onSearch={handleSearch}
        searchValue={search}
        searchPlaceholder="Search by customer, agent, or phone..."
        filters={filters}
        activeFilters={activeFilters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
      />

      <DataTable
        columns={columns}
        data={data}
        isLoading={getFundsQuery.isLoading}
        currentPage={page}
        totalItems={totalItems}
        pageSize={pageSize}
        onPageChange={setPage}
        onPageSizeChange={handlePageSizeChange}
        onRowClick={(row) => router.push(`/dashboard/get-funds/${row.id}` as never)}
        emptyState={{
          icon: Wallet,
          title: "No get funds cases found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => {
          const actions: TableActionItem[] = [
            {
              label: "View details",
              icon: Eye,
              onSelect: () => router.push(`/dashboard/get-funds/${row.id}` as never),
            },
          ];

          return (
            <TableActionMenu
              actions={actions}
              triggerLabel={`Open actions for ${row.borrower_name}`}
            />
          );
        }}
      />
    </div>
  );
}
