"use client";

import { Loader2 } from "lucide-react";

export interface ConfirmModalProps {
  title: string;
  description: string;
  confirmLabel: string;
  confirmClassName?: string;
  isLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmModal({
  title,
  description,
  confirmLabel,
  confirmClassName = "bg-red-600 text-white hover:bg-red-700",
  isLoading = false,
  onConfirm,
  onCancel,
}: ConfirmModalProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
      <div className="border-border bg-card mx-4 w-full max-w-sm rounded-2xl border p-6 shadow-xl">
        <h2 className="text-foreground mb-2 text-base font-semibold">{title}</h2>
        <p className="text-muted-foreground mb-6 text-sm">{description}</p>
        <div className="flex gap-3">
          <button
            onClick={onCancel}
            disabled={isLoading}
            className="border-border text-foreground hover:bg-muted flex-1 rounded-xl border px-4 py-2.5 text-sm font-medium transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={isLoading}
            className={`flex flex-1 items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-medium transition-colors disabled:opacity-50 ${confirmClassName}`}
          >
            {isLoading && <Loader2 size={13} className="animate-spin" />}
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
