"use client";

import { useState, useCallback, useMemo } from "react";
import { useRouter } from "next/navigation";
import { Users, CheckCircle, XCircle, Eye, Ban } from "lucide-react";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import {
  useApproveAgentApplication,
  useDeactivateUser,
  useRejectAgentApplication,
  useUsersList,
} from "@/hooks/use-users";
import { useApproveKyc, useRejectKyc } from "@/hooks/use-kyc";
import { formatDate, formatPhone } from "@/lib/format";
import type { AppUser, UserKycSummary } from "@/lib/types";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu, type TableActionItem } from "@/components/dashboard/table-action-menu";
import { Badge } from "@/components/ui/badge";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";

const filters: FilterDefinition[] = [
  {
    label: "Role",
    key: "role",
    options: [
      { label: "User", value: "user" },
      { label: "Agent", value: "agent" },
    ],
  },
  {
    label: "Account Status",
    key: "is_active",
    options: [
      { label: "Active", value: "true" },
      { label: "Inactive", value: "false" },
    ],
  },
  {
    label: "KYC Status",
    key: "kyc_status",
    options: [
      { label: "Not submitted", value: "none" },
      { label: "Pending", value: "pending" },
      { label: "Approved", value: "approved" },
      { label: "Rejected", value: "rejected" },
    ],
  },
];

const STATUS_VARIANT: Record<string, "muted" | "warning" | "success" | "destructive"> = {
  none: "muted",
  pending: "warning",
  approved: "success",
  rejected: "destructive",
};

const columns: Column<AppUser>[] = [
  {
    key: "full_name",
    label: "Name",
    primaryOnMobile: true,
    render: (_, row) => (
      <span className="font-medium">
        {row.full_name || `${row.first_name} ${row.last_name}`.trim() || "—"}
      </span>
    ),
  },
  {
    key: "phone",
    label: "Phone",
    width: "180px",
    render: (_, row) => formatPhone(row.phone),
  },
  {
    key: "role",
    label: "Role",
    render: (_, row) => <Badge variant={row.role === "agent" ? "info" : "muted"}>{row.role}</Badge>,
  },
  {
    key: "kyc_status",
    label: "KYC Status",
    render: (_, row) => (
      <Badge variant={STATUS_VARIANT[row.kyc_status] ?? "muted"}>{row.kyc_status}</Badge>
    ),
  },
  {
    key: "kyc_submission",
    label: "Identity",
    hideOnMobile: true,
    render: (_, row) => (row.kyc_submission ? "Ghana Card" : "—"),
  },
  {
    key: "is_active",
    label: "Account",
    hideOnMobile: true,
    render: (_, row) =>
      row.is_active ? (
        <Badge variant="success">Yes</Badge>
      ) : (
        <Badge variant="destructive">No</Badge>
      ),
  },
  {
    key: "created_at",
    label: "Joined",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

type ModalAction =
  | { type: "approve-agent" | "reject-agent"; user: AppUser }
  | { type: "approve-kyc" | "reject-kyc"; user: AppUser; kyc: UserKycSummary }
  | { type: "deactivate"; user: AppUser }
  | null;
const FILTER_KEYS = filters.map((filter) => filter.key);

export default function UsersPage() {
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
  const usersQuery = useUsersList(queryInput);
  const approveAgentMutation = useApproveAgentApplication();
  const rejectAgentMutation = useRejectAgentApplication();
  const approveKycMutation = useApproveKyc();
  const rejectKycMutation = useRejectKyc();
  const deactivateUserMutation = useDeactivateUser();
  const [modal, setModal] = useState<ModalAction>(null);
  const actionLoading =
    approveAgentMutation.isPending ||
    rejectAgentMutation.isPending ||
    approveKycMutation.isPending ||
    rejectKycMutation.isPending ||
    deactivateUserMutation.isPending;
  const data = usersQuery.data?.results ?? [];
  const totalItems = usersQuery.data?.count ?? 0;

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
      switch (modal.type) {
        case "approve-agent":
          await approveAgentMutation.mutateAsync(modal.user.id);
          break;
        case "reject-agent":
          await rejectAgentMutation.mutateAsync(modal.user.id);
          break;
        case "approve-kyc":
          await approveKycMutation.mutateAsync(modal.kyc.id);
          break;
        case "reject-kyc":
          await rejectKycMutation.mutateAsync({ id: modal.kyc.id, reason });
          break;
        case "deactivate":
          await deactivateUserMutation.mutateAsync({ id: modal.user.id, reason: reason ?? "" });
          break;
      }
      setModal(null);
    } catch {
      // keep modal open on error
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">User Management</h1>
        <p className="text-muted-foreground text-sm">View and manage all platform users.</p>
      </div>

      <FilterBar
        onSearch={handleSearch}
        searchValue={search}
        searchPlaceholder="Search by name or phone number..."
        filters={filters}
        activeFilters={activeFilters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
      />

      <DataTable
        columns={columns}
        data={data}
        isLoading={usersQuery.isLoading}
        currentPage={page}
        totalItems={totalItems}
        pageSize={pageSize}
        onPageChange={setPage}
        onPageSizeChange={handlePageSizeChange}
        onRowClick={(row) => router.push(`/dashboard/users/${row.id}` as never)}
        emptyState={{
          icon: Users,
          title: "No users found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => {
          const displayName =
            row.full_name || `${row.first_name} ${row.last_name}`.trim() || formatPhone(row.phone);
          const menuActions: TableActionItem[] = [
            {
              label: "View details",
              icon: Eye,
              onSelect: () => router.push(`/dashboard/users/${row.id}` as never),
            },
          ];

          if (row.agent_status === "pending") {
            menuActions.push(
              {
                label: "Approve agent",
                icon: CheckCircle,
                onSelect: () => setModal({ type: "approve-agent", user: row }),
                separatorBefore: true,
              },
              {
                label: "Reject agent",
                icon: XCircle,
                onSelect: () => setModal({ type: "reject-agent", user: row }),
                destructive: true,
              },
            );
          }

          if (row.kyc_submission?.status === "pending") {
            menuActions.push(
              {
                label: "Approve KYC",
                icon: CheckCircle,
                onSelect: () =>
                  setModal({ type: "approve-kyc", user: row, kyc: row.kyc_submission! }),
                separatorBefore: true,
              },
              {
                label: "Reject KYC",
                icon: XCircle,
                onSelect: () =>
                  setModal({ type: "reject-kyc", user: row, kyc: row.kyc_submission! }),
                destructive: true,
              },
            );
          }

          if (row.kyc_status === "approved" && row.is_active) {
            menuActions.push({
              label: "Deactivate account",
              icon: Ban,
              onSelect: () => setModal({ type: "deactivate", user: row }),
              separatorBefore: true,
              destructive: true,
            });
          }

          return (
            <TableActionMenu
              actions={menuActions}
              triggerLabel={`Open actions for ${displayName}`}
            />
          );
        }}
      />

      {(modal?.type === "approve-agent" || modal?.type === "reject-agent") && (
        <ConfirmModal
          title={
            modal.type === "approve-agent"
              ? "Approve Agent Application"
              : "Reject Agent Application"
          }
          description={
            modal.type === "approve-agent"
              ? `Are you sure you want to approve ${modal.user.full_name || formatPhone(modal.user.phone)} as an agent? This will grant them agent permissions.`
              : `Are you sure you want to reject the agent application from ${modal.user.full_name || formatPhone(modal.user.phone)}?`
          }
          confirmLabel={modal.type === "approve-agent" ? "Approve" : "Reject"}
          confirmVariant={modal.type === "approve-agent" ? "default" : "destructive"}
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setModal(null)}
        />
      )}
      {modal?.type === "approve-kyc" && (
        <ConfirmModal
          title="Approve KYC Submission"
          description={`Approve the identity verification for ${modal.user.full_name || formatPhone(modal.user.phone)}?`}
          confirmLabel="Approve"
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setModal(null)}
        />
      )}
      {modal?.type === "reject-kyc" && (
        <RejectModal
          title="Reject KYC Submission"
          description={`Provide a reason for rejecting ${modal.user.full_name || formatPhone(modal.user.phone)}'s identity verification.`}
          isLoading={actionLoading}
          onConfirm={handleAction}
          onCancel={() => setModal(null)}
        />
      )}
      {modal?.type === "deactivate" && (
        <RejectModal
          title="Deactivate Account"
          description={`Explain why ${modal.user.full_name || formatPhone(modal.user.phone)}'s account should be deactivated. They will no longer be able to sign in.`}
          reasonPlaceholder="Reason for deactivation (required)"
          confirmLabel="Deactivate"
          isLoading={actionLoading}
          onConfirm={handleAction}
          onCancel={() => setModal(null)}
        />
      )}
    </div>
  );
}
