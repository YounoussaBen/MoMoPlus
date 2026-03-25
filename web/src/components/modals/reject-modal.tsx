"use client";

import { useState } from "react";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";

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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[var(--overlay-strong)] backdrop-blur-md">
      <div className="border-border/70 bg-card/96 mx-4 w-full max-w-sm rounded-2xl border p-6 backdrop-blur-xl">
        <h2 className="text-foreground mb-2 text-base font-semibold">{title}</h2>
        <p className="text-muted-foreground mb-4 text-sm">{description}</p>
        <Textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Reason for rejection (required)"
          rows={3}
          className="mb-4 min-h-[108px] text-sm shadow-none"
        />
        <div className="flex gap-3">
          <Button onClick={onCancel} disabled={isLoading} variant="outline" className="flex-1">
            Cancel
          </Button>
          <Button
            onClick={() => onConfirm(reason)}
            disabled={isLoading || !reason.trim()}
            variant="destructive"
            className="flex-1"
          >
            {isLoading && <Loader2 size={13} className="animate-spin" />}
            Reject
          </Button>
        </div>
      </div>
    </div>
  );
}
