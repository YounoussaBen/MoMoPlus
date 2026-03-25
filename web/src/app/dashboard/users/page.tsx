"use client";

import { useState, useEffect, useCallback } from "react";
import { Users, CheckCircle, XCircle, MoreHorizontal } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { AppUser, PaginatedResponse } from "@/lib/types";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { Badge } from "@/components/ui/badge";
import { ConfirmModal } from "@/components/modals/confirm-modal";

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
    label: "Agent Status",
    key: "agent_status",
    options: [
      { label: "None", value: "none" },
      { label: "Pending", value: "pending" },
      { label: "Approved", value: "approved" },
      { label: "Rejected", value: "rejected" },
    ],
  },
  {
    label: "Active",
    key: "is_active",
    options: [
      { label: "Active", value: "true" },
      { label: "Inactive", value: "false" },
    ],
  },
];

const AGENT_STATUS_VARIANT: Record<string, "muted" | "warning" | "success" | "destructive"> = {
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
  { key: "email", label: "Email", wrap: true, width: "200px" },
  {
    key: "role",
    label: "Role",
    render: (_, row) => <Badge variant={row.role === "agent" ? "info" : "muted"}>{row.role}</Badge>,
  },
  {
    key: "agent_status",
    label: "Agent Status",
    render: (_, row) => (
      <Badge variant={AGENT_STATUS_VARIANT[row.agent_status] ?? "muted"}>{row.agent_status}</Badge>
    ),
  },
  {
    key: "is_active",
    label: "Active",
    hideOnMobile: true,
    render: (_, row) =>
      row.is_active ? (
        <span className="text-green-600">Yes</span>
      ) : (
        <span className="text-red-500">No</span>
      ),
  },
  {
    key: "created_at",
    label: "Joined",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

type ModalAction = { type: "approve" | "reject"; user: AppUser } | null;

export default function UsersPage() {
  const [data, setData] = useState<AppUser[]>([]);
  const [totalItems, setTotalItems] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeFilters, setActiveFilters] = useState<Record<string, string>>({});
  const [modal, setModal] = useState<ModalAction>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const fetchUsers = useCallback(async () => {
    setIsLoading(true);
    try {
      const params = new URLSearchParams();
      params.set("page", String(page));
      params.set("page_size", String(pageSize));
      if (search) params.set("search", search);
      Object.entries(activeFilters).forEach(([key, value]) => {
        if (value) params.set(key, value);
      });

      const res = await apiFetch<PaginatedResponse<AppUser>>(
        `/api/staff/users/?${params.toString()}`,
      );
      setData(res.results);
      setTotalItems(res.count);
    } catch {
      setData([]);
      setTotalItems(0);
    } finally {
      setIsLoading(false);
    }
  }, [page, pageSize, search, activeFilters]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

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

  const handleAction = async () => {
    if (!modal) return;
    setActionLoading(true);
    try {
      const endpoint =
        modal.type === "approve"
          ? `/api/staff/users/${modal.user.id}/approve-agent/`
          : `/api/staff/users/${modal.user.id}/reject-agent/`;
      await apiFetch(endpoint, { method: "POST" });
      setModal(null);
      fetchUsers();
    } catch {
      // error handled silently, modal stays open
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-foreground text-2xl font-bold">User Management</h1>
        <p className="text-muted-foreground text-sm">
          View and manage all platform users, approve or reject agent applications.
        </p>
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
        emptyState={{
          icon: Users,
          title: "No users found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) =>
          row.agent_status === "pending" ? (
            <div className="flex items-center gap-1">
              <button
                onClick={() => setModal({ type: "approve", user: row })}
                className="rounded-lg p-1.5 text-green-600 transition-colors hover:bg-green-500/10"
                title="Approve agent"
              >
                <CheckCircle size={18} />
              </button>
              <button
                onClick={() => setModal({ type: "reject", user: row })}
                className="rounded-lg p-1.5 text-red-500 transition-colors hover:bg-red-500/10"
                title="Reject agent"
              >
                <XCircle size={18} />
              </button>
            </div>
          ) : (
            <button
              className="text-muted-foreground hover:bg-muted rounded-lg p-1.5 transition-colors"
              title="More options"
            >
              <MoreHorizontal size={18} />
            </button>
          )
        }
      />

      {modal && (
        <ConfirmModal
          title={
            modal.type === "approve" ? "Approve Agent Application" : "Reject Agent Application"
          }
          description={
            modal.type === "approve"
              ? `Are you sure you want to approve ${modal.user.full_name || modal.user.email} as an agent? This will grant them agent permissions.`
              : `Are you sure you want to reject the agent application from ${modal.user.full_name || modal.user.email}?`
          }
          confirmLabel={modal.type === "approve" ? "Approve" : "Reject"}
          confirmClassName={
            modal.type === "approve"
              ? "bg-green-600 text-white hover:bg-green-700"
              : "bg-red-600 text-white hover:bg-red-700"
          }
          isLoading={actionLoading}
          onConfirm={handleAction}
          onCancel={() => setModal(null)}
        />
      )}
    </div>
  );
}
