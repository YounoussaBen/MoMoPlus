"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { UserCog, CheckCircle, XCircle, Eye } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type {
  AppUser,
  AgentCertification,
  CertificationStatus,
  PaginatedResponse,
} from "@/lib/types";
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

type AgentRow = AppUser & { cert_status: CertificationStatus | "none" };

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
  const [data, setData] = useState<AgentRow[]>([]);
  const [totalItems, setTotalItems] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeFilters, setActiveFilters] = useState<Record<string, string>>({});
  const [modal, setModal] = useState<ModalAction>(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [certMap, setCertMap] = useState<Record<string, AgentCertification>>({});

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      const params = new URLSearchParams();
      params.set("page", String(page));
      params.set("page_size", String(pageSize));
      params.set("role", "agent");
      if (search) params.set("search", search);
      Object.entries(activeFilters).forEach(([key, value]) => {
        if (value && key !== "certified") params.set(key, value);
      });
      const res = await apiFetch<PaginatedResponse<AppUser>>(
        `/api/staff/users/?${params.toString()}`,
      );

      // Fetch certifications for the displayed agents
      const emails = res.results.map((u) => u.email);
      const certs: Record<string, AgentCertification> = {};
      if (emails.length > 0) {
        try {
          const certRes = await apiFetch<PaginatedResponse<AgentCertification>>(
            `/api/staff/agents/certifications/?page_size=100`,
          );
          for (const cert of certRes.results) {
            if (emails.includes(cert.agent_email)) {
              certs[cert.agent_email] = cert;
            }
          }
        } catch {
          /* certifications unavailable */
        }
      }
      setCertMap(certs);

      // Merge cert status into rows
      const certFilter = activeFilters.certified;
      let rows: AgentRow[] = res.results.map((u) => ({
        ...u,
        cert_status: (certs[u.email]?.status ?? "none") as CertificationStatus | "none",
      }));

      // Client-side filter for certification status
      if (certFilter) {
        rows = rows.filter((r) => r.cert_status === certFilter);
      }

      setData(rows);
      setTotalItems(certFilter ? rows.length : res.count);
    } catch {
      setData([]);
      setTotalItems(0);
    } finally {
      setIsLoading(false);
    }
  }, [page, pageSize, search, activeFilters]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleSearch = useCallback((query: string) => {
    setSearch(query);
    setPage(1);
  }, []);

  const handleFilterChange = useCallback((key: string, value: string) => {
    setActiveFilters((prev) => ({ ...prev, [key]: value }));
    setPage(1);
  }, []);

  const handleClearFilters = useCallback(() => {
    setActiveFilters({});
    setPage(1);
  }, []);

  const handlePageSizeChange = useCallback((size: number) => {
    setPageSize(size);
    setPage(1);
  }, []);

  const handleAction = async (reason?: string) => {
    if (!modal) return;
    setActionLoading(true);
    try {
      let endpoint: string;
      let body: string | undefined;
      switch (modal.type) {
        case "approve_agent":
          endpoint = `/api/staff/users/${modal.user.id}/approve-agent/`;
          break;
        case "reject_agent":
          endpoint = `/api/staff/users/${modal.user.id}/reject-agent/`;
          break;
        case "approve_cert":
          endpoint = `/api/staff/agents/certifications/${modal.certId}/approve/`;
          break;
        case "reject_cert":
          endpoint = `/api/staff/agents/certifications/${modal.certId}/reject/`;
          if (reason) body = JSON.stringify({ reason });
          break;
      }
      await apiFetch(endpoint, { method: "POST", body });
      setModal(null);
      fetchData();
    } catch {
      /* keep modal open on error */
    } finally {
      setActionLoading(false);
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
        searchPlaceholder="Search by name or email..."
        filters={filters}
        activeFilters={activeFilters}
        onFilterChange={handleFilterChange}
        onClearFilters={handleClearFilters}
      />

      <DataTable
        columns={columns}
        data={data}
        isLoading={isLoading}
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
          confirmClassName="bg-green-600 text-white hover:bg-green-700"
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
          confirmClassName="bg-green-600 text-white hover:bg-green-700"
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
