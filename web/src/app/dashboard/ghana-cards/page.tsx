"use client";

import { useEffect, useMemo, useState } from "react";
import { BadgeCheck, Eye, Pencil, Power, Trash2 } from "lucide-react";
import {
  useDeleteGhanaCard,
  useGhanaCardDetail,
  useGhanaCardsList,
  useToggleGhanaCard,
} from "@/hooks/use-ghana-cards";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import { getErrorMessage } from "@/lib/errors";
import { formatDate } from "@/lib/format";
import type { GhanaCardRecord } from "@/lib/types";
import { GhanaCardDetailModal } from "@/components/dashboard/ghana-card-detail-modal";
import { GhanaCardFormModal } from "@/components/dashboard/ghana-card-form-modal";
import { ConfirmModal } from "@/components/modals/confirm-modal";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu } from "@/components/dashboard/table-action-menu";
import { useToast } from "@/components/ui/toast";

const filters: FilterDefinition[] = [
  {
    label: "Status",
    key: "is_active",
    options: [
      { label: "Active", value: "true" },
      { label: "Inactive", value: "false" },
    ],
  },
];

const columns: Column<GhanaCardRecord>[] = [
  {
    key: "masked_card_number",
    label: "Ghana Card",
    primaryOnMobile: true,
    render: (_, row) => <span className="font-medium">{row.masked_card_number}</span>,
  },
  {
    key: "surname",
    label: "Cardholder",
    render: (_, row) => `${row.first_names} ${row.surname}`.trim(),
  },
  {
    key: "date_of_birth",
    label: "Date of birth",
    hideOnMobile: true,
    render: (_, row) => (row.date_of_birth ? formatDate(row.date_of_birth) : "—"),
  },
  {
    key: "sex",
    label: "Sex",
    hideOnMobile: true,
    render: (_, row) => (row.sex === "F" ? "Female" : row.sex === "M" ? "Male" : row.sex || "—"),
  },
  {
    key: "is_active",
    label: "Status",
    render: (_, row) => (
      <Badge variant={row.is_active ? "success" : "muted"}>
        {row.is_active ? "Active" : "Inactive"}
      </Badge>
    ),
  },
  {
    key: "created_at",
    label: "Added",
    hideOnMobile: true,
    render: (_, row) => formatDate(row.created_at),
  },
];

type RecordModal = "create" | "view" | "edit" | null;

export default function GhanaCardsPage() {
  const [recordModal, setRecordModal] = useState<RecordModal>(null);
  const [selectedRecordId, setSelectedRecordId] = useState<string | null>(null);
  const [recordToDelete, setRecordToDelete] = useState<GhanaCardRecord | null>(null);
  const { error } = useToast();
  const toggleMutation = useToggleGhanaCard();
  const deleteMutation = useDeleteGhanaCard();

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
  } = useTableUrlState({ filterKeys: filters.map((filter) => filter.key) });
  const queryInput = useMemo(
    () => ({ page, pageSize, search, activeFilters }),
    [activeFilters, page, pageSize, search],
  );
  const query = useGhanaCardsList(queryInput);
  const detailQuery = useGhanaCardDetail(selectedRecordId ?? "");

  useEffect(() => {
    if (query.error) {
      error("Could not load registry", getErrorMessage(query.error, "Please try again."));
    }
  }, [error, query.error]);

  const openCreate = () => {
    setSelectedRecordId(null);
    setRecordModal("create");
  };

  const openDetails = (id: string) => {
    setSelectedRecordId(id);
    setRecordModal("view");
  };

  const openEdit = (id: string) => {
    setSelectedRecordId(id);
    setRecordModal("edit");
  };

  const closeRecordModal = () => {
    setRecordModal(null);
    setSelectedRecordId(null);
  };

  const handleDelete = async () => {
    if (!recordToDelete) return;
    try {
      await deleteMutation.mutateAsync(recordToDelete.id);
      setRecordToDelete(null);
    } catch {
      // The mutation displays the API error and keeps the confirmation open.
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-foreground text-2xl font-bold">Verification Registry</h1>
          <p className="text-muted-foreground text-sm">
            Maintain the trusted Ghana Card records used for automatic onboarding verification.
          </p>
        </div>
        <Button onClick={openCreate}>
          <BadgeCheck className="size-4" />
          Add card
        </Button>
      </div>

      <Card className="border-border/60 bg-card/82 border backdrop-blur-xl">
        <CardContent className="p-4 sm:p-5">
          <FilterBar
            onSearch={setSearch}
            searchValue={search}
            searchPlaceholder="Search by card number or cardholder name..."
            filters={filters}
            activeFilters={activeFilters}
            onFilterChange={setFilter}
            onClearFilters={clearFilters}
          />
        </CardContent>
      </Card>

      <DataTable
        columns={columns}
        data={query.data?.results ?? []}
        isLoading={query.isLoading}
        currentPage={queryInput.page}
        totalItems={query.data?.count ?? 0}
        pageSize={queryInput.pageSize}
        onPageChange={setPage}
        onPageSizeChange={setPageSize}
        emptyState={{
          icon: BadgeCheck,
          title: "No registry records found",
          description: "Add a Ghana Card or adjust your search and filters.",
        }}
        actions={(row) => (
          <TableActionMenu
            actions={[
              {
                label: "View details",
                icon: Eye,
                onSelect: () => openDetails(row.id),
              },
              {
                label: "Edit record",
                icon: Pencil,
                onSelect: () => openEdit(row.id),
              },
              {
                label: row.is_active ? "Deactivate" : "Activate",
                icon: Power,
                destructive: row.is_active,
                separatorBefore: true,
                disabled: toggleMutation.isPending,
                onSelect: () => toggleMutation.mutate({ id: row.id, isActive: !row.is_active }),
              },
              {
                label: "Delete record",
                icon: Trash2,
                destructive: true,
                disabled: deleteMutation.isPending,
                onSelect: () => setRecordToDelete(row),
              },
            ]}
          />
        )}
      />

      <GhanaCardDetailModal
        open={recordModal === "view"}
        record={detailQuery.data ?? null}
        isLoading={detailQuery.isLoading}
        onClose={closeRecordModal}
        onEdit={() => setRecordModal("edit")}
      />

      <GhanaCardFormModal
        key={`${recordModal}-${selectedRecordId ?? "new"}-${detailQuery.data?.id ?? "loading"}`}
        open={recordModal === "create" || recordModal === "edit"}
        mode={recordModal === "edit" ? "edit" : "create"}
        record={recordModal === "edit" ? (detailQuery.data ?? null) : null}
        onClose={closeRecordModal}
        onSaved={closeRecordModal}
      />

      {recordToDelete && (
        <ConfirmModal
          title="Delete registry record?"
          description={`Delete the Ghana Card record for ${recordToDelete.first_names} ${recordToDelete.surname}? This removes it from automatic verification.`}
          confirmLabel="Delete record"
          isLoading={deleteMutation.isPending}
          onConfirm={handleDelete}
          onCancel={() => setRecordToDelete(null)}
        />
      )}
    </div>
  );
}
