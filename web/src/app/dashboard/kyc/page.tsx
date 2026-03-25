"use client";

import { useState, useCallback, useMemo } from "react";
import { useRouter } from "next/navigation";
import { FileCheck, CheckCircle, XCircle, Eye } from "lucide-react";
import { useApproveKyc, useKycList, useRejectKyc } from "@/hooks/use-kyc";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import { formatDate, formatIdType } from "@/lib/format";
import type { KycSubmission } from "@/lib/types";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu, type TableActionItem } from "@/components/dashboard/table-action-menu";
import { Badge } from "@/components/ui/badge";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";

const filters: FilterDefinition[] = [
  {
    label: "Status",
    key: "status",
    options: [
      { label: "Pending", value: "pending" },
      { label: "Approved", value: "approved" },
      { label: "Rejected", value: "rejected" },
    ],
  },
  {
    label: "ID Type",
    key: "id_type",
    options: [
      { label: "Ghana Card", value: "national_id" },
      { label: "Passport", value: "passport" },
      { label: "Driver's License", value: "drivers_license" },
    ],
  },
];

const STATUS_VARIANT: Record<string, "muted" | "warning" | "success" | "destructive"> = {
  none: "muted",
  pending: "warning",
  approved: "success",
  rejected: "destructive",
};

const columns: Column<KycSubmission>[] = [
  {
    key: "id" as keyof KycSubmission,
    label: "Name",
    primaryOnMobile: true,
    render: (_, row) => (
      <span className="font-medium">
        {`${row.user.first_name} ${row.user.last_name}`.trim() || "—"}
      </span>
    ),
  },
  {
    key: "user",
    label: "Email",
    wrap: true,
    width: "200px",
    render: (_, row) => row.user.email,
  },
  {
    key: "id_type",
    label: "ID Type",
    hideOnMobile: true,
    render: (_, row) => formatIdType(row.id_type),
  },
  {
    key: "status",
    label: "Status",
    render: (_, row) => <Badge variant={STATUS_VARIANT[row.status] ?? "muted"}>{row.status}</Badge>,
  },
  {
    key: "created_at",
    label: "Submitted",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

type ModalAction = { type: "approve" | "reject"; kyc: KycSubmission } | null;
const FILTER_KEYS = filters.map((filter) => filter.key);

export default function KycPage() {
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
  const kycQuery = useKycList(queryInput);
  const approveKycMutation = useApproveKyc();
  const rejectKycMutation = useRejectKyc();
  const [modal, setModal] = useState<ModalAction>(null);
  const actionLoading = approveKycMutation.isPending || rejectKycMutation.isPending;
  const data = kycQuery.data?.results ?? [];
  const totalItems = kycQuery.data?.count ?? 0;

  const handleSearch = useCallback((query: string) => setSearch(query), [setSearch]);
  const handleFilterChange = useCallback(
    (key: string, value: string) => setFilter(key, value),
    [setFilter],
  );
  const handleClearFilters = useCallback(() => clearFilters(), [clearFilters]);
  const handlePageSizeChange = useCallback((size: number) => setPageSize(size), [setPageSize]);

  const handleAction = async (reason?: string) => {
    if (!modal) return;

    try {
      if (modal.type === "approve") {
        await approveKycMutation.mutateAsync(modal.kyc.id);
      } else {
        await rejectKycMutation.mutateAsync({ id: modal.kyc.id, reason });
      }
      setModal(null);
    } catch {
      /* keep modal open on error */
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">KYC Reviews</h1>
        <p className="text-muted-foreground text-sm">
          Review and process identity verification submissions.
        </p>
      </div>

      <FilterBar
        onSearch={handleSearch}
        searchValue={search}
        searchPlaceholder="Search by name or email..."
        filters={filters}
        activeFilters={activeFilters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
      />

      <DataTable
        columns={columns}
        data={data}
        isLoading={kycQuery.isLoading}
        currentPage={page}
        totalItems={totalItems}
        pageSize={pageSize}
        onPageChange={setPage}
        onPageSizeChange={handlePageSizeChange}
        onRowClick={(row) => router.push(`/dashboard/kyc/${row.user.id}` as never)}
        emptyState={{
          icon: FileCheck,
          title: "No KYC submissions found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => {
          const displayName =
            `${row.user.first_name} ${row.user.last_name}`.trim() || row.user.email;
          const menuActions: TableActionItem[] = [
            {
              label: "View details",
              icon: Eye,
              onSelect: () => router.push(`/dashboard/kyc/${row.user.id}` as never),
            },
          ];

          if (row.status === "pending") {
            menuActions.push(
              {
                label: "Approve KYC",
                icon: CheckCircle,
                onSelect: () => setModal({ type: "approve", kyc: row }),
                separatorBefore: true,
              },
              {
                label: "Reject KYC",
                icon: XCircle,
                onSelect: () => setModal({ type: "reject", kyc: row }),
                destructive: true,
              },
            );
          }

          return (
            <TableActionMenu
              actions={menuActions}
              triggerLabel={`Open actions for ${displayName}`}
            />
          );
        }}
      />

      {modal?.type === "approve" && (
        <ConfirmModal
          title="Approve KYC Submission"
          description={`Are you sure you want to approve the KYC submission from ${`${modal.kyc.user.first_name} ${modal.kyc.user.last_name}`.trim() || modal.kyc.user.email}?`}
          confirmLabel="Approve"
          confirmVariant="default"
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setModal(null)}
        />
      )}
      {modal?.type === "reject" && (
        <RejectModal
          title="Reject KYC Submission"
          description={`Provide a reason for rejecting the KYC submission from ${`${modal.kyc.user.first_name} ${modal.kyc.user.last_name}`.trim() || modal.kyc.user.email}.`}
          isLoading={actionLoading}
          onConfirm={(reason) => handleAction(reason)}
          onCancel={() => setModal(null)}
        />
      )}
    </div>
  );
}
