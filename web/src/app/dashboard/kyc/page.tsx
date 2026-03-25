"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { FileCheck, CheckCircle, XCircle, Eye } from "lucide-react";
import { apiFetch } from "@/lib/api";
import { formatDate, formatIdType } from "@/lib/format";
import type { KycSubmission, PaginatedResponse } from "@/lib/types";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
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

export default function KycPage() {
  const router = useRouter();
  const [data, setData] = useState<KycSubmission[]>([]);
  const [totalItems, setTotalItems] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeFilters, setActiveFilters] = useState<Record<string, string>>({});
  const [modal, setModal] = useState<ModalAction>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      const params = new URLSearchParams();
      params.set("page", String(page));
      params.set("page_size", String(pageSize));
      if (search) params.set("search", search);
      Object.entries(activeFilters).forEach(([key, value]) => {
        if (value) params.set(key, value);
      });
      const res = await apiFetch<PaginatedResponse<KycSubmission>>(
        `/api/staff/kyc/?${params.toString()}`,
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
      const endpoint =
        modal.type === "approve"
          ? `/api/staff/kyc/${modal.kyc.id}/approve/`
          : `/api/staff/kyc/${modal.kyc.id}/reject/`;
      await apiFetch(endpoint, {
        method: "POST",
        body: modal.type === "reject" && reason ? JSON.stringify({ reason }) : undefined,
      });
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
        <h1 className="text-foreground text-2xl font-bold">KYC Reviews</h1>
        <p className="text-muted-foreground text-sm">
          Review and process identity verification submissions.
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
        onRowClick={(row) => router.push(`/dashboard/kyc/${row.user.id}` as never)}
        emptyState={{
          icon: FileCheck,
          title: "No KYC submissions found",
          description: "Try adjusting your search or filters.",
        }}
        actions={(row) => (
          <div className="flex items-center gap-1">
            {row.status === "pending" && (
              <>
                <button
                  onClick={() => setModal({ type: "approve", kyc: row })}
                  className="rounded-lg p-1.5 text-green-600 transition-colors hover:bg-green-500/10"
                  title="Approve KYC"
                >
                  <CheckCircle size={18} />
                </button>
                <button
                  onClick={() => setModal({ type: "reject", kyc: row })}
                  className="rounded-lg p-1.5 text-red-500 transition-colors hover:bg-red-500/10"
                  title="Reject KYC"
                >
                  <XCircle size={18} />
                </button>
              </>
            )}
            <button
              onClick={() => router.push(`/dashboard/kyc/${row.user.id}` as never)}
              className="text-muted-foreground hover:bg-muted rounded-lg p-1.5 transition-colors"
              title="View user details"
            >
              <Eye size={18} />
            </button>
          </div>
        )}
      />

      {modal?.type === "approve" && (
        <ConfirmModal
          title="Approve KYC Submission"
          description={`Are you sure you want to approve the KYC submission from ${`${modal.kyc.user.first_name} ${modal.kyc.user.last_name}`.trim() || modal.kyc.user.email}?`}
          confirmLabel="Approve"
          confirmClassName="bg-green-600 text-white hover:bg-green-700"
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
