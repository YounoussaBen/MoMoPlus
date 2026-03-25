"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { Users, CheckCircle, XCircle, Eye } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { AppUser, PaginatedResponse } from "@/lib/types";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu, type TableActionItem } from "@/components/dashboard/table-action-menu";
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
    label: "Active",
    key: "is_active",
    options: [
      { label: "Active", value: "true" },
      { label: "Inactive", value: "false" },
    ],
  },
];

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
  const router = useRouter();
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
      // keep modal open on error
    } finally {
      setActionLoading(false);
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
        onRowClick={(row) => router.push(`/dashboard/users/${row.id}` as never)}
        emptyState={{
          icon: Users,
          title: "No users found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => {
          const displayName =
            row.full_name || `${row.first_name} ${row.last_name}`.trim() || row.email;
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
                onSelect: () => setModal({ type: "approve", user: row }),
                separatorBefore: true,
              },
              {
                label: "Reject agent",
                icon: XCircle,
                onSelect: () => setModal({ type: "reject", user: row }),
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
