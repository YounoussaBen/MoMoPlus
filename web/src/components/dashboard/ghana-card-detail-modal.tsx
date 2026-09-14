"use client";

import { ExternalLink, Image as ImageIcon, Loader2, Pencil } from "lucide-react";
import type { GhanaCardRecordDetail } from "@/lib/types";
import { formatDate } from "@/lib/format";
import { ContentViewerModal, useContentViewer } from "@/components/modals/content-viewer-modal";
import { DocCard, InfoRow } from "@/components/dashboard/user-detail-shared";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";

interface GhanaCardDetailModalProps {
  open: boolean;
  record: GhanaCardRecordDetail | null;
  isLoading: boolean;
  onClose: () => void;
  onEdit: () => void;
}

export function GhanaCardDetailModal({
  open,
  record,
  isLoading,
  onClose,
  onEdit,
}: GhanaCardDetailModalProps) {
  const viewer = useContentViewer();

  return (
    <>
      <Modal
        open={open}
        onClose={onClose}
        title="Verification registry details"
        description="Review the complete Ghana Card record and both uploaded images."
        className="max-w-4xl"
      >
        {isLoading || !record ? (
          <div className="text-muted-foreground flex min-h-72 items-center justify-center gap-2 text-sm">
            <Loader2 className="size-4 animate-spin" /> Loading record…
          </div>
        ) : (
          <div className="min-h-0 flex-1 space-y-6 overflow-y-auto px-5 py-6 sm:px-7">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p className="text-foreground text-lg font-semibold">
                  {record.first_names} {record.surname}
                </p>
                <p className="text-muted-foreground mt-1 text-sm">{record.card_number}</p>
              </div>
              <div className="flex items-center gap-2">
                <Badge variant={record.is_active ? "success" : "muted"}>
                  {record.is_active ? "Active" : "Inactive"}
                </Badge>
                <Button variant="outline" size="sm" onClick={onEdit}>
                  <Pencil className="size-3.5" /> Edit record
                </Button>
              </div>
            </div>

            <div className="border-border/60 bg-muted/20 grid gap-4 rounded-2xl border p-4 sm:grid-cols-2">
              <InfoRow label="First names">{record.first_names}</InfoRow>
              <InfoRow label="Surname">{record.surname}</InfoRow>
              <InfoRow label="Ghana Card number">{record.card_number}</InfoRow>
              <InfoRow label="Date of birth">
                {record.date_of_birth ? formatDate(record.date_of_birth) : "—"}
              </InfoRow>
              <InfoRow label="Sex">
                {record.sex === "F" ? "Female" : record.sex === "M" ? "Male" : record.sex || "—"}
              </InfoRow>
              <InfoRow label="Added">{formatDate(record.created_at)}</InfoRow>
              <InfoRow label="Last updated">{formatDate(record.updated_at)}</InfoRow>
            </div>

            <div>
              <div className="mb-3 flex items-center justify-between gap-3">
                <p className="text-foreground text-sm font-medium">Uploaded card images</p>
                <span className="text-muted-foreground inline-flex items-center gap-1.5 text-xs">
                  <ImageIcon className="size-3.5" /> Select an image to enlarge
                </span>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <DocCard
                  label="Ghana Card front"
                  fileUrl={record.card_front_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
                <DocCard
                  label="Ghana Card back"
                  fileUrl={record.card_back_url}
                  onView={(url, title) => viewer.open(url, title, "IMAGE")}
                />
              </div>
            </div>

            <div className="text-muted-foreground border-border/60 bg-muted/20 flex items-start gap-2 rounded-xl border p-3 text-xs leading-5">
              <ExternalLink className="mt-0.5 size-3.5 shrink-0" />
              Image links are temporary and are refreshed whenever this detail view is opened.
            </div>
          </div>
        )}
      </Modal>
      <ContentViewerModal
        url={viewer.url}
        title={viewer.title}
        type={viewer.type}
        isOpen={viewer.isOpen}
        onClose={viewer.close}
      />
    </>
  );
}
