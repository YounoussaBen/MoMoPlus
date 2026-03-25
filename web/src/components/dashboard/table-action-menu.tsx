"use client";

import { Fragment } from "react";
import { type LucideIcon } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";

export interface TableActionItem {
  label: string;
  onSelect: () => void;
  icon?: LucideIcon;
  disabled?: boolean;
  destructive?: boolean;
  separatorBefore?: boolean;
}

interface TableActionMenuProps {
  actions: TableActionItem[];
  triggerLabel?: string;
}

export function TableActionMenu({
  actions,
  triggerLabel = "Open actions menu",
}: TableActionMenuProps) {
  if (actions.length === 0) return null;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          aria-label={triggerLabel}
          className="text-muted-foreground focus-visible:ring-primary/20 inline-flex h-9 min-w-9 items-center justify-center rounded-full px-2 focus-visible:ring-2 focus-visible:outline-none"
        >
          <span aria-hidden className="text-lg leading-none">
            ...
          </span>
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        align="end"
        sideOffset={10}
        className="min-w-[220px] rounded-2xl border-0 bg-white p-2 shadow-[0_20px_50px_-20px_rgba(15,23,42,0.28)]"
      >
        {actions.map((action, index) => {
          const Icon = action.icon;

          return (
            <Fragment key={`${action.label}-${index}`}>
              {action.separatorBefore && index > 0 ? <div className="h-1.5" /> : null}
              <DropdownMenuItem
                disabled={action.disabled}
                onSelect={action.onSelect}
                className={cn(
                  "rounded-xl px-3 py-3 text-sm font-medium text-slate-700 focus:bg-transparent focus:text-slate-700",
                  action.destructive && "text-red-600 focus:text-red-600",
                )}
              >
                {Icon ? (
                  <Icon
                    size={15}
                    className={action.destructive ? "text-red-500" : "text-slate-500"}
                  />
                ) : null}
                <span>{action.label}</span>
              </DropdownMenuItem>
            </Fragment>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
