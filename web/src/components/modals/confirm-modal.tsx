"use client";

import { Loader2 } from "lucide-react";
import { Button, type ButtonProps } from "@/components/ui/button";

export interface ConfirmModalProps {
  title: string;
  description: string;
  confirmLabel: string;
  confirmVariant?: ButtonProps["variant"];
  isLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmModal({
  title,
  description,
  confirmLabel,
  confirmVariant = "destructive",
  isLoading = false,
  onConfirm,
  onCancel,
}: ConfirmModalProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[var(--overlay-strong)] backdrop-blur-md">
      <div className="border-border/70 bg-card/96 mx-4 w-full max-w-sm rounded-2xl border p-6 backdrop-blur-xl">
        <h2 className="text-foreground mb-2 text-base font-semibold">{title}</h2>
        <p className="text-muted-foreground mb-6 text-sm">{description}</p>
        <div className="flex gap-3">
          <Button onClick={onCancel} disabled={isLoading} variant="outline" className="flex-1">
            Cancel
          </Button>
          <Button
            onClick={onConfirm}
            disabled={isLoading}
            variant={confirmVariant}
            className="flex-1"
          >
            {isLoading && <Loader2 size={13} className="animate-spin" />}
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
