"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { Menu, Settings, LogOut, ChevronDown } from "lucide-react";

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
          ? "mb-6 rounded-2xl bg-[#f4faf0] p-4 md:mb-8 md:p-6"
          : "mb-6 rounded-2xl bg-[#f4faf0] p-4 md:mb-8 md:p-6"
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
          {/* Profile */}
          <div className="relative" ref={profileRef}>
            <button
              onClick={() => setProfileOpen((prev) => !prev)}
              className="flex h-11 items-center gap-2 px-3 md:h-12 md:gap-3 md:px-4"
            >
              <div className="hidden text-right md:block">
                <p className="text-foreground max-w-[120px] truncate text-sm font-medium">
                  {userName}
                </p>
                <p className="text-muted-foreground truncate text-xs">{userEmail}</p>
              </div>

              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#2d6a2d] text-sm font-semibold text-white md:h-10 md:w-10">
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
                  <div className="bg-card absolute -top-[9px] right-5 h-4 w-4 rotate-45" />
                  <div className="bg-card border-border overflow-hidden rounded-xl border">
                    <div className="border-border border-b px-4 py-3">
                      <p className="text-foreground truncate text-sm font-semibold">{userName}</p>
                      <p className="text-muted-foreground mt-0.5 truncate text-xs">{userEmail}</p>
                    </div>
                    <div className="py-1">
                      <Link
                        href={settingsHref as never}
                        onClick={() => setProfileOpen(false)}
                        className="text-foreground hover:bg-muted flex items-center gap-3 px-4 py-2.5 text-sm transition-colors"
                      >
                        <Settings size={15} className="text-muted-foreground" />
                        Settings
                      </Link>
                      <button
                        onClick={() => {
                          setProfileOpen(false);
                          onLogout();
                        }}
                        className="flex w-full items-center gap-3 px-4 py-2.5 text-sm text-red-600 transition-colors hover:bg-red-50"
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
