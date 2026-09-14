"use client";

import { AlertCircle, CheckCircle2, Info, X, type LucideIcon } from "lucide-react";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { cn } from "@/lib/utils";

export type ToastVariant = "success" | "error" | "info";

export interface ToastOptions {
  title: string;
  description?: string;
  variant?: ToastVariant;
  duration?: number;
}

interface ToastItem extends ToastOptions {
  id: string;
}

interface ToastContextValue {
  toast: (options: ToastOptions) => string;
  dismiss: (id: string) => void;
  success: (title: string, description?: string) => string;
  error: (title: string, description?: string) => string;
  info: (title: string, description?: string) => string;
}

const ToastContext = createContext<ToastContextValue | null>(null);
let nextToastId = 0;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);

  const dismiss = useCallback((id: string) => {
    setItems((current) => current.filter((item) => item.id !== id));
  }, []);

  const toast = useCallback((options: ToastOptions) => {
    const id = `toast-${Date.now()}-${nextToastId++}`;
    setItems((current) =>
      [
        ...current,
        {
          ...options,
          id,
          variant: options.variant ?? "info",
          duration: options.duration ?? 5200,
        },
      ].slice(-5),
    );
    return id;
  }, []);

  const success = useCallback(
    (title: string, description?: string) => toast({ title, description, variant: "success" }),
    [toast],
  );
  const error = useCallback(
    (title: string, description?: string) => toast({ title, description, variant: "error" }),
    [toast],
  );
  const info = useCallback(
    (title: string, description?: string) => toast({ title, description, variant: "info" }),
    [toast],
  );

  const value = useMemo(
    () => ({ toast, dismiss, success, error, info }),
    [dismiss, error, info, success, toast],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <ToastViewport items={items} onDismiss={dismiss} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return context;
}

function ToastViewport({
  items,
  onDismiss,
}: {
  items: ToastItem[];
  onDismiss: (id: string) => void;
}) {
  return (
    <div
      className="pointer-events-none fixed top-4 right-4 z-[100] flex w-[calc(100vw-2rem)] max-w-sm flex-col gap-3 sm:top-6 sm:right-6"
      aria-label="Notifications"
      aria-live="polite"
      role="region"
    >
      {items.map((item) => (
        <ToastCard key={item.id} item={item} onDismiss={onDismiss} />
      ))}
    </div>
  );
}

function ToastCard({ item, onDismiss }: { item: ToastItem; onDismiss: (id: string) => void }) {
  const [offset, setOffset] = useState(0);
  const startX = useRef<number | null>(null);
  const Icon: LucideIcon =
    item.variant === "success" ? CheckCircle2 : item.variant === "error" ? AlertCircle : Info;

  useEffect(() => {
    const timeout = window.setTimeout(() => onDismiss(item.id), item.duration ?? 5200);
    return () => window.clearTimeout(timeout);
  }, [item.duration, item.id, onDismiss]);

  return (
    <div
      className={cn(
        "border-border/70 bg-card/96 text-card-foreground pointer-events-auto relative flex items-start gap-3 overflow-hidden rounded-2xl border p-4 shadow-[var(--shadow-popover)] backdrop-blur-xl transition-[transform,opacity] duration-200",
        item.variant === "success" && "border-success/30",
        item.variant === "error" && "border-destructive/35",
        item.variant === "info" && "border-info/30",
      )}
      role={item.variant === "error" ? "alert" : "status"}
      style={{
        transform: `translateX(${offset}px)`,
        opacity: Math.max(0.4, 1 - Math.abs(offset) / 240),
        touchAction: "pan-y",
      }}
      onPointerDown={(event) => {
        startX.current = event.clientX;
        event.currentTarget.setPointerCapture(event.pointerId);
      }}
      onPointerMove={(event) => {
        if (startX.current === null) return;
        setOffset(event.clientX - startX.current);
      }}
      onPointerUp={(event) => {
        if (startX.current === null) return;
        const distance = event.clientX - startX.current;
        startX.current = null;
        if (Math.abs(distance) > 80) {
          onDismiss(item.id);
        } else {
          setOffset(0);
        }
      }}
      onPointerCancel={() => {
        startX.current = null;
        setOffset(0);
      }}
    >
      <Icon
        className={cn(
          "mt-0.5 size-5 shrink-0",
          item.variant === "success" && "text-success",
          item.variant === "error" && "text-destructive",
          item.variant === "info" && "text-info",
        )}
        aria-hidden="true"
      />
      <div className="min-w-0 flex-1">
        <p className="text-foreground text-sm font-semibold">{item.title}</p>
        {item.description && (
          <p className="text-muted-foreground mt-1 text-sm leading-5">{item.description}</p>
        )}
      </div>
      <button
        type="button"
        className="text-muted-foreground hover:bg-muted hover:text-foreground -mt-1 -mr-1 flex size-8 shrink-0 items-center justify-center rounded-lg transition-colors"
        onClick={() => onDismiss(item.id)}
        aria-label="Dismiss notification"
      >
        <X className="size-4" />
      </button>
    </div>
  );
}
