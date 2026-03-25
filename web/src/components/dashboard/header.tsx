"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { Menu, Settings, LogOut, ChevronDown } from "lucide-react";
import { ThemeToggle } from "@/components/theme/theme-toggle";

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
  const profileRef = useRef<HTMLDivElement>(null);

  const initials = userName
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (profileRef.current && !profileRef.current.contains(event.target as Node)) {
        setProfileOpen(false);
      }
    }
    if (profileOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () => document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [profileOpen]);

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
          <div className="relative" ref={profileRef}>
            <button
              onClick={() => setProfileOpen((prev) => !prev)}
              className="hover:bg-accent/65 flex h-11 items-center gap-2 rounded-full px-3 transition-colors md:h-12 md:gap-3 md:px-4"
            >
              <div className="hidden text-right md:block">
                <p className="text-foreground max-w-30 truncate text-sm font-medium">{userName}</p>
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

            {profileOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setProfileOpen(false)} />
                <div className="absolute top-full right-0 z-50 mt-3 w-56">
                  <div className="bg-popover border-border/70 absolute -top-2.25 right-5 h-4 w-4 rotate-45 border-t border-l" />
                  <div className="bg-popover border-border/70 overflow-hidden rounded-2xl border backdrop-blur-xl">
                    <div className="border-border/70 border-b px-4 py-3">
                      <p className="text-foreground truncate text-sm font-semibold">{userName}</p>
                      <p className="text-muted-foreground mt-0.5 truncate text-xs">{userEmail}</p>
                    </div>
                    <div className="py-1">
                      <Link
                        href={settingsHref as never}
                        onClick={() => setProfileOpen(false)}
                        className="text-foreground hover:bg-accent/70 flex items-center gap-3 px-4 py-2.5 text-sm transition-colors"
                      >
                        <Settings size={15} className="text-muted-foreground" />
                        Settings
                      </Link>
                      <button
                        onClick={() => {
                          setProfileOpen(false);
                          onLogout();
                        }}
                        className="text-destructive hover:bg-destructive/10 flex w-full items-center gap-3 px-4 py-2.5 text-sm transition-colors"
                      >
                        <LogOut size={15} />
                        Sign out
                      </button>
                    </div>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
