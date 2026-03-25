"use client";

import { useCallback, useMemo } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeftRight, Eye } from "lucide-react";
import { useCashServicesList } from "@/hooks/use-cash-services";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import {
  formatCurrency,
  formatDate,
  formatNetwork,
  formatTransactionStatus,
  formatTransactionType,
} from "@/lib/format";
import type { StaffPhysicalTransaction } from "@/lib/types";
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
      { label: "Accepted", value: "accepted" },
      { label: "Completed", value: "completed" },
      { label: "Rejected", value: "rejected" },
      { label: "Cancelled", value: "cancelled" },
      { label: "Expired", value: "expired" },
    ],
  },
  {
    label: "Type",
    key: "transaction_type",
    options: [
      { label: "Cash Out", value: "cash_out" },
      { label: "Cash In", value: "deposit" },
    ],
  },
  {
    label: "Meeting",
    key: "has_meeting",
    options: [
      { label: "Meeting set", value: "true" },
      { label: "No meeting", value: "false" },
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
];

const STATUS_VARIANT: Record<string, "muted" | "warning" | "info" | "success" | "destructive"> = {
  pending: "warning",
  accepted: "info",
  completed: "success",
  rejected: "destructive",
  cancelled: "muted",
  expired: "destructive",
};

const columns: Column<StaffPhysicalTransaction>[] = [
  {
    key: "user_name",
    label: "Customer",
    primaryOnMobile: true,
    render: (_, row) => (
      <div>
        <p className="font-medium">{row.user_name || "—"}</p>
        <p className="text-muted-foreground text-xs">{row.user_email}</p>
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
    key: "transaction_type",
    label: "Type",
    render: (_, row) => <Badge variant="info">{formatTransactionType(row.transaction_type)}</Badge>,
  },
  {
    key: "status",
    label: "Status",
    render: (_, row) => (
      <Badge variant={STATUS_VARIANT[row.status] ?? "muted"}>
        {formatTransactionStatus(row.status)}
      </Badge>
    ),
  },
  {
    key: "amount",
    label: "Amount",
    render: (_, row) => (
      <div>
        <p className="font-medium">{formatCurrency(row.amount)}</p>
        <p className="text-muted-foreground text-xs">{formatNetwork(row.network)}</p>
      </div>
    ),
  },
  {
    key: "has_meeting",
    label: "Meeting",
    hideOnMobile: true,
    render: (_, row) => (
      <Badge variant={row.has_meeting ? "success" : "muted"}>
        {row.has_meeting ? "Set" : "Pending"}
      </Badge>
    ),
  },
  {
    key: "created_at",
    label: "Created",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

const FILTER_KEYS = filters.map((filter) => filter.key);

export default function CashServicesPage() {
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
    defaultPageSize: 20,
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

  const cashServicesQuery = useCashServicesList(queryInput);
  const data = cashServicesQuery.data?.results ?? [];
  const totalItems = cashServicesQuery.data?.count ?? 0;

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
        <h1 className="text-foreground text-2xl font-bold">Cash Services</h1>
        <p className="text-muted-foreground text-sm">
          Monitor physical cash-in and cash-out cases, meeting progress, and confirmation state.
        </p>
      </div>

      <FilterBar
        onSearch={handleSearch}
        searchValue={search}
        searchPlaceholder="Search by user, agent, phone, or meeting note..."
        filters={filters}
        activeFilters={activeFilters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
      />

      <DataTable
        columns={columns}
        data={data}
        isLoading={cashServicesQuery.isLoading}
        currentPage={page}
        totalItems={totalItems}
        pageSize={pageSize}
        onPageChange={setPage}
        onPageSizeChange={handlePageSizeChange}
        onRowClick={(row) => router.push(`/dashboard/cash-services/${row.id}` as never)}
        emptyState={{
          icon: ArrowLeftRight,
          title: "No cash service cases found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => {
          const actions: TableActionItem[] = [
            {
              label: "View details",
              icon: Eye,
              onSelect: () => router.push(`/dashboard/cash-services/${row.id}` as never),
            },
          ];

          return (
            <TableActionMenu actions={actions} triggerLabel={`Open actions for ${row.user_name}`} />
          );
        }}
      />
    </div>
  );
}
