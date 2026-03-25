"use client";

import { useState, useCallback, useMemo } from "react";
import { useRouter } from "next/navigation";
import { UserCog, CheckCircle, XCircle, Eye } from "lucide-react";
import {
  type AgentRow,
  useAgentsList,
  useApproveAgent,
  useApproveCertification,
  useRejectAgent,
  useRejectCertification,
} from "@/hooks/use-agents";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import { formatDate } from "@/lib/format";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu, type TableActionItem } from "@/components/dashboard/table-action-menu";
import { Badge } from "@/components/ui/badge";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { RejectModal } from "@/components/modals/reject-modal";

const filters: FilterDefinition[] = [
  {
    label: "Agent Status",
    key: "agent_status",
    options: [
      { label: "Pending", value: "pending" },
      { label: "Approved", value: "approved" },
      { label: "Rejected", value: "rejected" },
    ],
  },
  {
    label: "Certified",
    key: "certified",
    options: [
      { label: "Self Enrolled", value: "none" },
      { label: "Approved", value: "approved" },
      { label: "Pending", value: "pending" },
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
const FILTER_KEYS = filters.map((filter) => filter.key);

const columns: Column<AgentRow>[] = [
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
  { key: "email", label: "Email", wrap: true, width: "200px" },
  {
    key: "agent_status",
    label: "Agent Status",
    render: (_, row) => (
      <Badge variant={STATUS_VARIANT[row.agent_status] ?? "muted"}>{row.agent_status}</Badge>
    ),
  },
  {
    key: "cert_status" as keyof AgentRow,
    label: "Certified",
    render: (_, row) => (
      <Badge variant={STATUS_VARIANT[row.cert_status] ?? "muted"}>
        {row.cert_status === "none" ? "self enrolled" : row.cert_status}
      </Badge>
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
  | { type: "approve_agent" | "reject_agent"; user: AgentRow }
  | { type: "approve_cert" | "reject_cert"; user: AgentRow; certId: string }
  | null;

export default function AgentsPage() {
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
  const agentsQuery = useAgentsList(queryInput);
  const approveAgentMutation = useApproveAgent();
  const rejectAgentMutation = useRejectAgent();
  const approveCertificationMutation = useApproveCertification();
  const rejectCertificationMutation = useRejectCertification();
  const [modal, setModal] = useState<ModalAction>(null);
  const actionLoading =
    approveAgentMutation.isPending ||
    rejectAgentMutation.isPending ||
    approveCertificationMutation.isPending ||
    rejectCertificationMutation.isPending;
  const data = agentsQuery.data?.rows ?? [];
  const totalItems = agentsQuery.data?.totalItems ?? 0;
  const certMap = agentsQuery.data?.certMap ?? {};

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
        case "approve_agent":
          await approveAgentMutation.mutateAsync(modal.user.id);
          break;
        case "reject_agent":
          await rejectAgentMutation.mutateAsync(modal.user.id);
          break;
        case "approve_cert":
          await approveCertificationMutation.mutateAsync(modal.certId);
          break;
        case "reject_cert":
          await rejectCertificationMutation.mutateAsync({
            id: modal.certId,
            reason,
          });
          break;
      }
      setModal(null);
    } catch {
      /* keep modal open on error */
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">Agent Management</h1>
        <p className="text-muted-foreground text-sm">View and manage all agents on the platform.</p>
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
        isLoading={agentsQuery.isLoading}
        currentPage={page}
        totalItems={totalItems}
        pageSize={pageSize}
        onPageChange={setPage}
        onPageSizeChange={handlePageSizeChange}
        onRowClick={(row) => router.push(`/dashboard/agents/${row.id}` as never)}
        emptyState={{
          icon: UserCog,
          title: "No agents found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => {
          const displayName =
            row.full_name || `${row.first_name} ${row.last_name}`.trim() || row.email;
          const certification = certMap[row.email];
          const menuActions: TableActionItem[] = [
            {
              label: "View details",
              icon: Eye,
              onSelect: () => router.push(`/dashboard/agents/${row.id}` as never),
            },
          ];

          if (row.agent_status === "pending") {
            menuActions.push(
              {
                label: "Approve agent",
                icon: CheckCircle,
                onSelect: () => setModal({ type: "approve_agent", user: row }),
                separatorBefore: true,
              },
              {
                label: "Reject agent",
                icon: XCircle,
                onSelect: () => setModal({ type: "reject_agent", user: row }),
                destructive: true,
              },
            );
          }

          if (row.cert_status === "pending" && certification) {
            menuActions.push(
              {
                label: "Approve certification",
                icon: CheckCircle,
                onSelect: () =>
                  setModal({
                    type: "approve_cert",
                    user: row,
                    certId: certification.id,
                  }),
                separatorBefore: true,
              },
              {
                label: "Reject certification",
                icon: XCircle,
                onSelect: () =>
                  setModal({
                    type: "reject_cert",
                    user: row,
                    certId: certification.id,
                  }),
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

      {/* Agent approve */}
      {modal?.type === "approve_agent" && (
        <ConfirmModal
          title="Approve Agent Application"
          description={`Are you sure you want to approve ${modal.user.full_name || modal.user.email} as an agent?`}
          confirmLabel="Approve"
          confirmVariant="default"
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setModal(null)}
        />
      )}
      {/* Agent reject */}
      {modal?.type === "reject_agent" && (
        <ConfirmModal
          title="Reject Agent Application"
          description={`Are you sure you want to reject the agent application from ${modal.user.full_name || modal.user.email}?`}
          confirmLabel="Reject"
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setModal(null)}
        />
      )}
      {/* Certification approve */}
      {modal?.type === "approve_cert" && (
        <ConfirmModal
          title="Approve Certification"
          description={`Are you sure you want to certify ${modal.user.full_name || modal.user.email}?`}
          confirmLabel="Approve"
          confirmVariant="default"
          isLoading={actionLoading}
          onConfirm={() => handleAction()}
          onCancel={() => setModal(null)}
        />
      )}
      {/* Certification reject */}
      {modal?.type === "reject_cert" && (
        <RejectModal
          title="Reject Certification"
          description={`Provide a reason for rejecting the certification from ${modal.user.full_name || modal.user.email}.`}
          isLoading={actionLoading}
          onConfirm={(reason) => handleAction(reason)}
          onCancel={() => setModal(null)}
        />
      )}
    </div>
  );
}
