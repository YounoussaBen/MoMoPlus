"use client";

import { useState } from "react";
import Link from "next/link";
import { Menu, Settings, LogOut, ChevronDown } from "lucide-react";
import { ThemeToggle } from "@/components/theme/theme-toggle";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface HeaderProps {
  userName: string;
  userEmail: string;
  subtitle?: string;
  settingsHref?: string;
  onToggleSidebar?: () => void;
  onLogout: () => void | Promise<void>;
  flat?: boolean;
}

export function Header({
  userName,
  userEmail,
  subtitle,
  settingsHref = "/dashboard/settings",
  onToggleSidebar,
  onLogout,
  flat = false,
}: HeaderProps) {
  const [profileOpen, setProfileOpen] = useState(false);

  const initials = userName
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  return (
    <div
      className={
        flat
          ? "border-border/60 bg-sidebar/78 mb-6 rounded-2xl border p-4 backdrop-blur-xl md:mb-8 md:p-6"
          : "border-border/60 bg-sidebar/78 mb-6 rounded-2xl border p-4 backdrop-blur-xl md:mb-8 md:p-6"
      }
    >
      <div className="flex items-center justify-between gap-3">
        {onToggleSidebar && (
          <button
            onClick={onToggleSidebar}
            className="text-muted-foreground hover:bg-muted hover:text-foreground flex h-10 w-10 shrink-0 items-center justify-center rounded-lg transition-colors lg:hidden"
            aria-label="Toggle sidebar"
          >
            <Menu size={20} />
          </button>
        )}

        <div className="min-w-0 shrink">
          <h1 className="text-foreground truncate text-lg font-bold md:text-xl">
            Hi, {userName}! Welcome Back.
          </h1>
          {subtitle && (
            <p className="text-muted-foreground mt-0.5 truncate text-xs md:mt-1 md:text-sm">
              {subtitle}
            </p>
          )}
        </div>

        <div className="flex shrink-0 items-center gap-3">
          <ThemeToggle compact />

          {/* Profile */}
          <DropdownMenu open={profileOpen} onOpenChange={setProfileOpen}>
            <DropdownMenuTrigger asChild>
              <button className="hover:bg-accent/65 flex h-11 items-center gap-2 rounded-full px-3 transition-colors md:h-12 md:gap-3 md:px-4">
                <div className="hidden text-right md:block">
                  <p className="text-foreground max-w-30 truncate text-sm font-medium">
                    {userName}
                  </p>
                  <p className="text-muted-foreground truncate text-xs">{userEmail}</p>
                </div>

                <div className="bg-primary text-primary-foreground flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-semibold md:h-10 md:w-10">
                  {initials}
                </div>

                <ChevronDown
                  size={14}
                  className={`text-muted-foreground hidden transition-transform duration-200 md:block ${
                    profileOpen ? "rotate-180" : ""
                  }`}
                />
              </button>
            </DropdownMenuTrigger>

            <DropdownMenuContent
              align="end"
              sideOffset={12}
              className="border-border/70 bg-popover/95 w-56 overflow-hidden rounded-2xl border p-0 backdrop-blur-xl"
            >
              <div className="border-border/70 border-b px-4 py-3">
                <p className="text-foreground truncate text-sm font-semibold">{userName}</p>
                <p className="text-muted-foreground mt-0.5 truncate text-xs">{userEmail}</p>
              </div>

              <div className="p-1">
                <DropdownMenuItem asChild className="rounded-xl px-3 py-2.5">
                  <Link
                    href={settingsHref as never}
                    className="text-foreground flex items-center gap-3"
                  >
                    <Settings size={15} className="text-muted-foreground" />
                    Settings
                  </Link>
                </DropdownMenuItem>

                <DropdownMenuItem
                  onSelect={() => void onLogout()}
                  className="text-destructive focus:text-destructive rounded-xl px-3 py-2.5"
                >
                  <LogOut size={15} />
                  Sign out
                </DropdownMenuItem>
              </div>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </div>
  );
}
