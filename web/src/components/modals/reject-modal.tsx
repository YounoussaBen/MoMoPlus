"use client";

import { useState } from "react";
import { Loader2 } from "lucide-react";

export interface RejectModalProps {
  title: string;
  description: string;
  isLoading?: boolean;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
}

export function RejectModal({
  title,
  description,
  isLoading = false,
  onConfirm,
  onCancel,
}: RejectModalProps) {
  const [reason, setReason] = useState("");

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
      <div className="border-border bg-card mx-4 w-full max-w-sm rounded-2xl border p-6 shadow-xl">
        <h2 className="text-foreground mb-2 text-base font-semibold">{title}</h2>
        <p className="text-muted-foreground mb-4 text-sm">{description}</p>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Reason for rejection (required)"
          rows={3}
          className="border-border bg-background text-foreground placeholder:text-muted-foreground focus:border-ring focus:ring-ring/20 mb-4 w-full resize-none rounded-xl border px-4 py-3 text-sm focus:ring-2 focus:outline-none"
        />
        <div className="flex gap-3">
          <button
            onClick={onCancel}
            disabled={isLoading}
            className="border-border text-foreground hover:bg-muted flex-1 rounded-xl border px-4 py-2.5 text-sm font-medium transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={() => onConfirm(reason)}
            disabled={isLoading || !reason.trim()}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-red-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-red-700 disabled:opacity-50"
          >
            {isLoading && <Loader2 size={13} className="animate-spin" />}
            Reject
          </button>
        </div>
      </div>
    </div>
  );
}
