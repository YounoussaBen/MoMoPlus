"use client";

import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import {
  BadgeCheck,
  ChevronDown,
  ImagePlus,
  Loader2,
  Plus,
  Power,
  Trash2,
  UploadCloud,
} from "lucide-react";
import {
  useCreateGhanaCard,
  useDeleteGhanaCardImage,
  useGhanaCardsList,
  useToggleGhanaCard,
  useUploadGhanaCardImage,
} from "@/hooks/use-ghana-cards";
import { useTableUrlState } from "@/hooks/use-table-url-state";
import { getErrorMessage } from "@/lib/errors";
import { formatDate } from "@/lib/format";
import type { GhanaCardRecord } from "@/lib/types";
import { CalendarDatePicker } from "@/components/ui/calendar-date-picker";
import { Modal } from "@/components/ui/modal";
import { useToast } from "@/components/ui/toast";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { DataTable, type Column } from "@/components/dashboard/data-table";
import { FilterBar, type FilterDefinition } from "@/components/dashboard/filter-bar";
import { TableActionMenu } from "@/components/dashboard/table-action-menu";

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

const cardNumberPattern = /^GHA(?:[\s-]?\d){10}$/i;

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

type ImageSide = "front" | "back";

interface ImageUploadState {
  file: File;
  previewUrl: string;
  assetId: string | null;
  isUploading: boolean;
}

function formatCardNumber(digits: string) {
  const normalized = digits.replace(/\D/g, "").slice(0, 10);
  return normalized.length > 9 ? `${normalized.slice(0, 9)}-${normalized.slice(9)}` : normalized;
}

function getCardNumberValue(digits: string) {
  return `GHA-${formatCardNumber(digits)}`;
}

export default function GhanaCardsPage() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [cardDigits, setCardDigits] = useState("");
  const [firstNames, setFirstNames] = useState("");
  const [surname, setSurname] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [sex, setSex] = useState("");
  const [frontImage, setFrontImage] = useState<ImageUploadState | null>(null);
  const [backImage, setBackImage] = useState<ImageUploadState | null>(null);
  const uploadVersion = useRef({ front: 0, back: 0 });
  const previewUrls = useRef(new Set<string>());
  const { success, error } = useToast();
  const uploadMutation = useUploadGhanaCardImage();
  const deleteMutation = useDeleteGhanaCardImage();
  const createMutation = useCreateGhanaCard();
  const toggleMutation = useToggleGhanaCard();

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
  const query = useGhanaCardsList({ page, pageSize, search, activeFilters });

  useEffect(() => {
    const urls = previewUrls.current;
    return () => {
      urls.forEach((url) => URL.revokeObjectURL(url));
    };
  }, []);

  useEffect(() => {
    if (query.error) {
      error("Could not load registry", getErrorMessage(query.error, "Please try again."));
    }
  }, [error, query.error]);

  const revokePreview = useCallback((state: ImageUploadState | null) => {
    if (!state) return;
    URL.revokeObjectURL(state.previewUrl);
    previewUrls.current.delete(state.previewUrl);
  }, []);

  const getImageState = useCallback(
    (side: ImageSide) => (side === "front" ? frontImage : backImage),
    [backImage, frontImage],
  );

  const setImageState = useCallback((side: ImageSide, state: ImageUploadState | null) => {
    if (side === "front") setFrontImage(state);
    else setBackImage(state);
  }, []);

  const deleteAsset = useCallback(
    async (assetId: string, label: string) => {
      try {
        await deleteMutation.mutateAsync(assetId);
        return true;
      } catch (deleteError) {
        error(
          `Could not remove ${label.toLowerCase()}`,
          getErrorMessage(deleteError, "Please try again."),
        );
        return false;
      }
    },
    [deleteMutation, error],
  );

  const handleImageChange = useCallback(
    async (side: ImageSide, file: File | null) => {
      if (!file) return;
      const label = side === "front" ? "Front image" : "Back image";
      if (!file.type.startsWith("image/")) {
        error("Choose an image file", `${label} must be a JPG, PNG, or another image format.`);
        return;
      }
      if (file.size > 10 * 1024 * 1024) {
        error("Image is too large", `${label} must be smaller than 10 MB.`);
        return;
      }

      const previous = getImageState(side);
      const version = ++uploadVersion.current[side];
      const previewUrl = URL.createObjectURL(file);
      previewUrls.current.add(previewUrl);
      setImageState(side, { file, previewUrl, assetId: null, isUploading: true });

      try {
        const assetId = await uploadMutation.mutateAsync(file);
        if (uploadVersion.current[side] !== version) {
          await deleteAsset(assetId, label);
          revokePreview({ file, previewUrl, assetId, isUploading: false });
          return;
        }

        if (previous?.assetId) {
          await deleteAsset(previous.assetId, label);
        }
        revokePreview(previous);
        setImageState(side, { file, previewUrl, assetId, isUploading: false });
        success(`${label} uploaded`, "You can change it or remove it before saving the record.");
      } catch (uploadError) {
        if (uploadVersion.current[side] === version) {
          revokePreview({ file, previewUrl, assetId: null, isUploading: true });
          setImageState(side, previous);
          error(
            `Could not upload ${label.toLowerCase()}`,
            getErrorMessage(uploadError, "Please try again."),
          );
        }
      }
    },
    [deleteAsset, error, getImageState, revokePreview, setImageState, success, uploadMutation],
  );

  const handleImageRemove = useCallback(
    (side: ImageSide) => {
      const current = getImageState(side);
      ++uploadVersion.current[side];
      setImageState(side, null);
      revokePreview(current);
      if (current?.assetId) {
        const label = side === "front" ? "Front image" : "Back image";
        void deleteAsset(current.assetId, label).then((removed) => {
          if (removed) success(`${label} removed`);
        });
      }
    },
    [deleteAsset, getImageState, revokePreview, setImageState, success],
  );

  const resetForm = useCallback(() => {
    ++uploadVersion.current.front;
    ++uploadVersion.current.back;
    revokePreview(frontImage);
    revokePreview(backImage);
    setCardDigits("");
    setFirstNames("");
    setSurname("");
    setDateOfBirth("");
    setSex("");
    setFrontImage(null);
    setBackImage(null);
  }, [backImage, frontImage, revokePreview]);

  const closeModal = useCallback(() => {
    if (createMutation.isPending) return;
    const uploads = [
      { assetId: frontImage?.assetId, label: "front image" },
      { assetId: backImage?.assetId, label: "back image" },
    ].filter((upload): upload is { assetId: string; label: string } => Boolean(upload.assetId));
    resetForm();
    setIsModalOpen(false);
    uploads.forEach(({ assetId, label }) => {
      void deleteAsset(assetId, label);
    });
  }, [backImage?.assetId, createMutation.isPending, deleteAsset, frontImage?.assetId, resetForm]);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const cardNumber = getCardNumberValue(cardDigits);
    if (!cardNumberPattern.test(cardNumber)) {
      error("Enter a complete Ghana Card number", "Enter the 10 digits after the GHA prefix.");
      return;
    }
    if (!firstNames.trim() || !surname.trim()) {
      error("Names are required", "Enter the first name and last name shown on the card.");
      return;
    }
    if (
      !frontImage?.assetId ||
      !backImage?.assetId ||
      frontImage.isUploading ||
      backImage.isUploading
    ) {
      error("Upload both card images", "Wait for the front and back images to finish uploading.");
      return;
    }

    try {
      await createMutation.mutateAsync({
        card_number: cardNumber,
        first_names: firstNames.trim(),
        surname: surname.trim(),
        date_of_birth: dateOfBirth || null,
        sex,
        card_front_id: frontImage.assetId,
        card_back_id: backImage.assetId,
      });
      resetForm();
      setIsModalOpen(false);
    } catch {
      // The mutation displays the API error as a toast and keeps the modal open.
    }
  };

  const queryInput = useMemo(
    () => ({ page, pageSize, search, activeFilters }),
    [activeFilters, page, pageSize, search],
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-foreground text-2xl font-bold">Verification Registry</h1>
          <p className="text-muted-foreground text-sm">
            Maintain the trusted Ghana Card records used for automatic onboarding verification.
          </p>
        </div>
        <Button onClick={() => setIsModalOpen(true)}>
          <Plus className="size-4" />
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
                label: row.is_active ? "Deactivate" : "Activate",
                icon: Power,
                destructive: row.is_active,
                disabled: toggleMutation.isPending,
                onSelect: () => toggleMutation.mutate({ id: row.id, isActive: !row.is_active }),
              },
            ]}
          />
        )}
      />

      <Modal
        open={isModalOpen}
        onClose={closeModal}
        title="Add to verification registry"
        description="Upload both sides of the Ghana Card now. Images are stored immediately and linked when you save the record."
        className="max-w-3xl"
        closeDisabled={createMutation.isPending}
      >
        <form onSubmit={handleSubmit} className="flex min-h-0 flex-1 flex-col">
          <div className="min-h-0 flex-1 space-y-6 overflow-y-auto px-5 py-6 sm:px-7">
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="First name" htmlFor="first-names">
                <Input
                  id="first-names"
                  value={firstNames}
                  onChange={(event) => setFirstNames(event.target.value)}
                  placeholder="Ernestina Korkor"
                  autoComplete="given-name"
                />
              </Field>
              <Field label="Last name" htmlFor="surname">
                <Input
                  id="surname"
                  value={surname}
                  onChange={(event) => setSurname(event.target.value)}
                  placeholder="Manortey"
                  autoComplete="family-name"
                />
              </Field>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Date of birth" htmlFor="date-of-birth">
                <CalendarDatePicker
                  id="date-of-birth"
                  value={dateOfBirth}
                  onChange={setDateOfBirth}
                  placeholder="Choose date of birth"
                  maxDate={new Date()}
                />
              </Field>
              <Field label="Sex" htmlFor="sex">
                <div className="relative">
                  <select
                    id="sex"
                    value={sex}
                    onChange={(event) => setSex(event.target.value)}
                    className="border-border bg-background/88 text-foreground focus-visible:ring-primary/20 h-11 w-full appearance-none rounded-xl border px-4 pr-10 text-sm transition-colors focus-visible:ring-2 focus-visible:outline-none"
                  >
                    <option value="">Select sex</option>
                    <option value="F">Female</option>
                    <option value="M">Male</option>
                  </select>
                  <ChevronDown className="text-muted-foreground pointer-events-none absolute top-1/2 right-4 size-4 -translate-y-1/2" />
                </div>
              </Field>
            </div>

            <div className="grid gap-3 sm:grid-cols-[9rem_minmax(0,1fr)] sm:items-center sm:gap-5">
              <Label htmlFor="card-number" className="sm:pt-0.5">
                Ghana Card number
              </Label>
              <div>
                <div className="border-border bg-background/88 focus-within:ring-primary/20 flex h-11 w-full overflow-hidden rounded-xl border transition-colors focus-within:ring-2">
                  <span className="bg-muted/55 text-foreground flex items-center border-r px-3 text-sm font-semibold tracking-wide">
                    GHA-
                  </span>
                  <Input
                    id="card-number"
                    value={formatCardNumber(cardDigits)}
                    onChange={(event) =>
                      setCardDigits(event.target.value.replace(/\D/g, "").slice(0, 10))
                    }
                    placeholder="123456789-0"
                    inputMode="numeric"
                    autoComplete="off"
                    maxLength={11}
                    className="h-full rounded-none border-0 bg-transparent px-3 shadow-none focus-visible:ring-0"
                    aria-describedby="card-number-help"
                  />
                </div>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <ImageUploadField
                id="card-front"
                label="Front image"
                image={frontImage}
                onChange={(file) => void handleImageChange("front", file)}
                onRemove={() => handleImageRemove("front")}
              />
              <ImageUploadField
                id="card-back"
                label="Back image"
                image={backImage}
                onChange={(file) => void handleImageChange("back", file)}
                onRemove={() => handleImageRemove("back")}
              />
            </div>
          </div>

          <div className="border-border/70 flex shrink-0 flex-col-reverse gap-3 border-t px-5 py-4 sm:flex-row sm:justify-end sm:px-7">
            <Button
              type="button"
              variant="outline"
              onClick={closeModal}
              disabled={createMutation.isPending}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? (
                <Loader2 className="size-4 animate-spin" />
              ) : (
                <BadgeCheck className="size-4" />
              )}
              {createMutation.isPending ? "Saving record…" : "Save record"}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

function Field({
  label,
  htmlFor,
  children,
}: {
  label: string;
  htmlFor: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={htmlFor}>{label}</Label>
      {children}
    </div>
  );
}

function ImageUploadField({
  id,
  label,
  image,
  onChange,
  onRemove,
}: {
  id: string;
  label: string;
  image: ImageUploadState | null;
  onChange: (file: File | null) => void;
  onRemove: () => void;
}) {
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <Label htmlFor={id}>{label}</Label>
        {image?.isUploading && (
          <span className="text-muted-foreground inline-flex items-center gap-1.5 text-xs">
            <Loader2 className="size-3 animate-spin" /> Uploading
          </span>
        )}
      </div>
      <div className="relative">
        <input
          id={id}
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={(event) => {
            onChange(event.target.files?.[0] ?? null);
            event.target.value = "";
          }}
        />
        <label
          htmlFor={id}
          className="border-border/80 bg-muted/25 hover:border-primary/50 hover:bg-muted/45 group relative flex min-h-44 cursor-pointer items-center justify-center overflow-hidden rounded-2xl border border-dashed transition-colors"
        >
          {image ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={image.previewUrl}
              alt={`${label} preview`}
              className="h-44 w-full object-contain"
            />
          ) : (
            <span className="text-muted-foreground flex flex-col items-center gap-2 px-5 text-center text-sm">
              <ImagePlus className="text-primary size-8" />
              <span>Choose {label.toLowerCase()}</span>
              <span className="text-xs">JPG or PNG, up to 10 MB</span>
            </span>
          )}
          {image?.isUploading && (
            <span className="bg-background/65 absolute inset-0 flex items-center justify-center backdrop-blur-[2px]">
              <span className="bg-card/95 text-foreground inline-flex items-center gap-2 rounded-full px-3 py-2 text-xs font-medium shadow-sm">
                <Loader2 className="size-3.5 animate-spin" />
                Uploading image
              </span>
            </span>
          )}
          {image && !image.isUploading && (
            <span className="bg-card/90 text-foreground absolute right-3 bottom-3 inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium shadow-sm">
              <UploadCloud className="size-3.5" /> Change image
            </span>
          )}
        </label>
        {image && (
          <button
            type="button"
            onClick={(event) => {
              event.preventDefault();
              event.stopPropagation();
              onRemove();
            }}
            className="bg-card/95 text-destructive hover:bg-destructive hover:text-destructive-foreground absolute top-3 right-3 flex size-9 items-center justify-center rounded-full shadow-sm transition-colors"
            aria-label={`Remove ${label.toLowerCase()}`}
          >
            <Trash2 className="size-4" />
          </button>
        )}
      </div>
    </div>
  );
}
