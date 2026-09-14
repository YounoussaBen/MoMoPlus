"use client";

import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import { BadgeCheck, ChevronDown, ImagePlus, Loader2, Trash2, UploadCloud } from "lucide-react";
import {
  useCreateGhanaCard,
  useDeleteGhanaCardImage,
  useUpdateGhanaCard,
  useUploadGhanaCardImage,
} from "@/hooks/use-ghana-cards";
import { getErrorMessage } from "@/lib/errors";
import type { GhanaCardRecordDetail } from "@/lib/types";
import { CalendarDatePicker } from "@/components/ui/calendar-date-picker";
import { Modal } from "@/components/ui/modal";
import { useToast } from "@/components/ui/toast";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type ImageSide = "front" | "back";

interface ImageUploadState {
  file: File | null;
  previewUrl: string;
  assetId: string | null;
  isUploading: boolean;
}

interface GhanaCardFormModalProps {
  open: boolean;
  mode: "create" | "edit";
  record: GhanaCardRecordDetail | null;
  onClose: () => void;
  onSaved: () => void;
}

const cardNumberPattern = /^GHA(?:[\s-]?\d){10}$/i;

function formatCardNumber(digits: string) {
  const normalized = digits.replace(/\D/g, "").slice(0, 10);
  return normalized.length > 9 ? `${normalized.slice(0, 9)}-${normalized.slice(9)}` : normalized;
}

function getCardNumberValue(digits: string) {
  return `GHA-${formatCardNumber(digits)}`;
}

function getCardDigits(cardNumber: string) {
  return cardNumber.replace(/\D/g, "").slice(0, 10);
}

function createExistingImage(url: string | null): ImageUploadState | null {
  return url
    ? {
        file: null,
        previewUrl: url,
        assetId: null,
        isUploading: false,
      }
    : null;
}

export function GhanaCardFormModal({
  open,
  mode,
  record,
  onClose,
  onSaved,
}: GhanaCardFormModalProps) {
  const [cardDigits, setCardDigits] = useState(() =>
    mode === "edit" ? getCardDigits(record?.card_number ?? "") : "",
  );
  const [firstNames, setFirstNames] = useState(() =>
    mode === "edit" ? (record?.first_names ?? "") : "",
  );
  const [surname, setSurname] = useState(() => (mode === "edit" ? (record?.surname ?? "") : ""));
  const [dateOfBirth, setDateOfBirth] = useState(() =>
    mode === "edit" ? (record?.date_of_birth ?? "") : "",
  );
  const [sex, setSex] = useState(() => (mode === "edit" ? (record?.sex ?? "") : ""));
  const [frontImage, setFrontImage] = useState<ImageUploadState | null>(() =>
    mode === "edit" ? createExistingImage(record?.card_front_url?.url ?? null) : null,
  );
  const [backImage, setBackImage] = useState<ImageUploadState | null>(() =>
    mode === "edit" ? createExistingImage(record?.card_back_url?.url ?? null) : null,
  );
  const uploadVersion = useRef({ front: 0, back: 0 });
  const previewUrls = useRef(new Set<string>());
  const { success, error } = useToast();
  const uploadMutation = useUploadGhanaCardImage();
  const deleteMutation = useDeleteGhanaCardImage();
  const createMutation = useCreateGhanaCard();
  const updateMutation = useUpdateGhanaCard();

  const getImageState = useCallback(
    (side: ImageSide) => (side === "front" ? frontImage : backImage),
    [backImage, frontImage],
  );

  const setImageState = useCallback((side: ImageSide, state: ImageUploadState | null) => {
    if (side === "front") setFrontImage(state);
    else setBackImage(state);
  }, []);

  const revokePreview = useCallback((state: ImageUploadState | null) => {
    if (!state || !state.previewUrl.startsWith("blob:")) return;
    URL.revokeObjectURL(state.previewUrl);
    previewUrls.current.delete(state.previewUrl);
  }, []);

  useEffect(() => {
    const urls = previewUrls.current;
    return () => {
      urls.forEach((url) => URL.revokeObjectURL(url));
    };
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

  const clearForm = useCallback(
    (deletePendingUploads: boolean) => {
      const uploads = [
        { assetId: frontImage?.assetId, label: "front image" },
        { assetId: backImage?.assetId, label: "back image" },
      ].filter((upload): upload is { assetId: string; label: string } => Boolean(upload.assetId));
      resetForm();
      if (deletePendingUploads) {
        uploads.forEach(({ assetId, label }) => {
          void deleteAsset(assetId, label);
        });
      }
    },
    [backImage?.assetId, deleteAsset, frontImage?.assetId, resetForm],
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

  const isSaving = createMutation.isPending || updateMutation.isPending;
  const isUploading = frontImage?.isUploading === true || backImage?.isUploading === true;
  const isWorking = isSaving || isUploading;

  const handleClose = () => {
    if (isWorking) return;
    clearForm(true);
    onClose();
  };

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
    if (!frontImage?.previewUrl || !backImage?.previewUrl || isUploading) {
      error("Upload both card images", "Wait for the front and back images to finish uploading.");
      return;
    }

    try {
      if (mode === "edit") {
        if (!record) return;
        await updateMutation.mutateAsync({
          id: record.id,
          input: {
            card_number: cardNumber,
            first_names: firstNames.trim(),
            surname: surname.trim(),
            date_of_birth: dateOfBirth || null,
            sex,
            ...(frontImage.assetId ? { card_front_id: frontImage.assetId } : {}),
            ...(backImage.assetId ? { card_back_id: backImage.assetId } : {}),
          },
        });
      } else {
        if (!frontImage.assetId || !backImage.assetId) {
          error(
            "Upload both card images",
            "Wait for the front and back images to finish uploading.",
          );
          return;
        }
        await createMutation.mutateAsync({
          card_number: cardNumber,
          first_names: firstNames.trim(),
          surname: surname.trim(),
          date_of_birth: dateOfBirth || null,
          sex,
          card_front_id: frontImage.assetId,
          card_back_id: backImage.assetId,
        });
      }
      clearForm(false);
      onSaved();
    } catch {
      // The mutation displays the API error as a toast and keeps the modal open.
    }
  };

  const isEditLoading = mode === "edit" && !record;

  return (
    <Modal
      open={open}
      onClose={handleClose}
      title={mode === "edit" ? "Edit verification record" : "Add to verification registry"}
      description={
        mode === "edit"
          ? "Update the card details or replace either uploaded image."
          : "Upload both sides of the Ghana Card now. Images are stored immediately and linked when you save the record."
      }
      className="max-w-3xl"
      closeDisabled={isWorking}
    >
      {isEditLoading ? (
        <div className="text-muted-foreground flex min-h-72 items-center justify-center gap-2 text-sm">
          <Loader2 className="size-4 animate-spin" /> Loading record…
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="flex min-h-0 flex-1 flex-col">
          <div className="min-h-0 flex-1 space-y-6 overflow-y-auto px-5 py-6 sm:px-7">
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="First name" htmlFor={`first-names-${mode}`}>
                <Input
                  id={`first-names-${mode}`}
                  value={firstNames}
                  onChange={(event) => setFirstNames(event.target.value)}
                  placeholder="Ernestina Korkor"
                  autoComplete="given-name"
                />
              </Field>
              <Field label="Last name" htmlFor={`surname-${mode}`}>
                <Input
                  id={`surname-${mode}`}
                  value={surname}
                  onChange={(event) => setSurname(event.target.value)}
                  placeholder="Manortey"
                  autoComplete="family-name"
                />
              </Field>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Date of birth" htmlFor={`date-of-birth-${mode}`}>
                <CalendarDatePicker
                  id={`date-of-birth-${mode}`}
                  value={dateOfBirth}
                  onChange={setDateOfBirth}
                  placeholder="Choose date of birth"
                  maxDate={new Date()}
                />
              </Field>
              <Field label="Sex" htmlFor={`sex-${mode}`}>
                <div className="relative">
                  <select
                    id={`sex-${mode}`}
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
              <Label htmlFor={`card-number-${mode}`} className="sm:pt-0.5">
                Ghana Card number
              </Label>
              <div className="border-border bg-background/88 focus-within:ring-primary/20 flex h-11 w-full overflow-hidden rounded-xl border transition-colors focus-within:ring-2">
                <span className="bg-muted/55 text-foreground flex items-center border-r px-3 text-sm font-semibold tracking-wide">
                  GHA-
                </span>
                <Input
                  id={`card-number-${mode}`}
                  value={formatCardNumber(cardDigits)}
                  onChange={(event) =>
                    setCardDigits(event.target.value.replace(/\D/g, "").slice(0, 10))
                  }
                  placeholder="123456789-0"
                  inputMode="numeric"
                  autoComplete="off"
                  maxLength={11}
                  className="h-full rounded-none border-0 bg-transparent px-3 shadow-none focus-visible:ring-0"
                />
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <ImageUploadField
                id={`card-front-${mode}`}
                label="Front image"
                image={frontImage}
                onChange={(file) => void handleImageChange("front", file)}
                onRemove={() => handleImageRemove("front")}
              />
              <ImageUploadField
                id={`card-back-${mode}`}
                label="Back image"
                image={backImage}
                onChange={(file) => void handleImageChange("back", file)}
                onRemove={() => handleImageRemove("back")}
              />
            </div>
          </div>

          <div className="border-border/70 flex shrink-0 flex-col-reverse gap-3 border-t px-5 py-4 sm:flex-row sm:justify-end sm:px-7">
            <Button type="button" variant="outline" onClick={handleClose} disabled={isWorking}>
              Cancel
            </Button>
            <Button type="submit" disabled={isWorking}>
              {isSaving ? (
                <Loader2 className="size-4 animate-spin" />
              ) : (
                <BadgeCheck className="size-4" />
              )}
              {isSaving ? "Saving record…" : mode === "edit" ? "Save changes" : "Save record"}
            </Button>
          </div>
        </form>
      )}
    </Modal>
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
