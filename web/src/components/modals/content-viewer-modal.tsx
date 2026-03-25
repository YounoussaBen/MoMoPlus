"use client";

import { useState, useEffect, useCallback } from "react";
import { X, ExternalLink, Video, FileText, Image as ImageIcon, AlertCircle } from "lucide-react";

type ContentType = "IMAGE" | "PDF";

export interface ContentViewerModalProps {
  url: string;
  title: string;
  type: ContentType;
  isOpen: boolean;
  onClose: () => void;
}

export function ContentViewerModal({ url, title, type, isOpen, onClose }: ContentViewerModalProps) {
  const [loadError, setLoadError] = useState(false);
  const [prevKey, setPrevKey] = useState("");

  const key = `${url}:${isOpen}`;
  if (key !== prevKey) {
    setPrevKey(key);
    if (loadError) setLoadError(false);
  }

  const handleEsc = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Escape" && isOpen) onClose();
    },
    [isOpen, onClose],
  );

  useEffect(() => {
    document.addEventListener("keydown", handleEsc);
    return () => document.removeEventListener("keydown", handleEsc);
  }, [handleEsc]);

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const TypeIcon = type === "IMAGE" ? ImageIcon : type === "PDF" ? FileText : Video;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-card relative m-4 flex h-[90vh] w-full max-w-7xl flex-col overflow-hidden rounded-xl shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="border-border bg-card flex shrink-0 items-center justify-between border-b px-6 py-4">
          <div className="flex min-w-0 flex-1 items-center gap-3">
            <TypeIcon size={16} className="text-muted-foreground" />
            <h2 className="text-foreground truncate text-base font-semibold">{title}</h2>
          </div>
          <div className="ml-4 flex shrink-0 items-center gap-2">
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-foreground hover:bg-accent flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-colors"
              title="Open in new tab"
              onClick={(e) => e.stopPropagation()}
            >
              <ExternalLink size={14} />
              <span className="hidden sm:inline">Open</span>
            </a>
            <button
              onClick={onClose}
              className="text-foreground hover:bg-accent flex h-10 w-10 items-center justify-center rounded-lg transition-colors"
              title="Close"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-hidden">
          {type === "IMAGE" &&
            (loadError ? (
              <FallbackUnavailable url={url} />
            ) : (
              <div className="bg-muted/30 flex h-full items-center justify-center p-4">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={url}
                  alt={title}
                  className="max-h-full max-w-full rounded-lg object-contain"
                  onError={() => setLoadError(true)}
                />
              </div>
            ))}
          {type === "PDF" && <iframe src={url} className="h-full w-full border-0" title={title} />}
        </div>
      </div>
    </div>
  );
}

function FallbackUnavailable({ url }: { url: string }) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 px-4 text-center">
      <AlertCircle size={40} className="text-destructive" />
      <p className="text-foreground text-sm font-medium">Preview not available</p>
      <a
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        className="bg-primary text-primary-foreground hover:bg-primary/90 flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-colors"
      >
        Open in new tab
        <ExternalLink size={13} />
      </a>
    </div>
  );
}

export function useContentViewer() {
  const [state, setState] = useState<{
    isOpen: boolean;
    url: string;
    title: string;
    type: ContentType;
  }>({ isOpen: false, url: "", title: "", type: "IMAGE" });

  const open = (url: string, title: string, type: ContentType) =>
    setState({ isOpen: true, url, title, type });

  const close = () => setState((s) => ({ ...s, isOpen: false }));

  return { ...state, open, close };
}
