"use client";

import { X } from "lucide-react";
import { useEffect, useId } from "react";
import { cn } from "@/lib/utils";

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: React.ReactNode;
  className?: string;
  closeDisabled?: boolean;
}

export function Modal({
  open,
  onClose,
  title,
  description,
  children,
  className,
  closeDisabled = false,
}: ModalProps) {
  const titleId = useId();
  const descriptionId = useId();

  useEffect(() => {
    if (!open) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !closeDisabled) onClose();
    };

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeDisabled, onClose, open]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-[var(--overlay-strong)] p-4 backdrop-blur-md sm:p-6"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !closeDisabled) onClose();
      }}
    >
      <div
        className={cn(
          "border-border/70 bg-card/98 relative flex max-h-[min(860px,calc(100vh-2rem))] w-full flex-col overflow-hidden rounded-3xl border shadow-[var(--shadow-modal)] backdrop-blur-xl sm:max-h-[calc(100vh-3rem)]",
          className,
        )}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={description ? descriptionId : undefined}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="border-border/70 flex shrink-0 items-start justify-between gap-4 border-b px-5 py-5 sm:px-7">
          <div className="min-w-0">
            <h2 id={titleId} className="text-foreground text-lg font-semibold tracking-tight">
              {title}
            </h2>
            {description && (
              <p id={descriptionId} className="text-muted-foreground mt-1.5 text-sm leading-5">
                {description}
              </p>
            )}
          </div>
          <button
            type="button"
            className="text-muted-foreground hover:bg-muted hover:text-foreground flex size-10 shrink-0 items-center justify-center rounded-xl transition-colors disabled:pointer-events-none disabled:opacity-50"
            onClick={onClose}
            disabled={closeDisabled}
            aria-label="Close dialog"
          >
            <X className="size-5" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
