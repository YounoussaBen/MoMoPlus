"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { ChevronLeft, ChevronRight, LogOut } from "lucide-react";
import type { LucideIcon } from "lucide-react";

export interface NavItem {
  icon: LucideIcon;
  label: string;
  href: string;
  exact?: boolean;
}

interface SidebarProps {
  navItems: NavItem[];
  bottomNavItems?: NavItem[];
  logoSrc?: string;
  logoCollapsedSrc?: string;
  mobileOpen: boolean;
  desktopCollapsed: boolean;
  onToggleMobile: () => void;
  onToggleDesktop: () => void;
  onLogout: () => void | Promise<void>;
}

export function Sidebar({
  navItems,
  bottomNavItems = [],
  logoSrc,
  logoCollapsedSrc,
  mobileOpen,
  desktopCollapsed,
  onToggleMobile,
  onToggleDesktop,
  onLogout,
}: SidebarProps) {
  const pathname = usePathname();

  const isActive = (item: NavItem) =>
    item.exact || item.href === "/" ? pathname === item.href : pathname.startsWith(item.href);

  return (
    <aside
      className={[
        "fixed top-0 z-50 flex h-screen flex-col bg-[#e8f5e0] py-6 transition-all duration-300",
        "w-64",
        mobileOpen ? "translate-x-0" : "-translate-x-full",
        "lg:sticky lg:translate-x-0",
        desktopCollapsed ? "lg:w-20 lg:items-center lg:px-2" : "lg:w-64 lg:px-4 lg:pl-6",
      ].join(" ")}
    >
      {/* Logo + toggle — expanded */}
      <div
        className={[
          "mt-2 mb-8 flex items-center justify-between p-2 px-2 transition-all duration-300",
          desktopCollapsed ? "lg:hidden" : "flex",
        ].join(" ")}
      >
        {logoSrc && <Image src={logoSrc} alt="Logo" width={140} height={35} className="shrink-0" />}
        <button
          onClick={onToggleDesktop}
          className="hidden h-8 w-8 items-center justify-center rounded-lg bg-black/5 text-[#6e6e73] transition-all duration-300 hover:bg-black/10 hover:text-[#111] lg:flex"
        >
          <ChevronLeft size={18} />
        </button>
      </div>

      {/* Logo + toggle — collapsed */}
      <div
        className={[
          "flex-col items-center transition-all duration-300",
          desktopCollapsed ? "hidden lg:flex" : "hidden",
        ].join(" ")}
      >
        {(logoCollapsedSrc ?? logoSrc) && (
          <div className="mt-2 p-2">
            <Image
              src={(logoCollapsedSrc ?? logoSrc)!}
              alt="Logo"
              width={40}
              height={40}
              className="shrink-0 rounded-lg object-contain"
            />
          </div>
        )}
        <div className="mt-4 mb-8">
          <button
            onClick={onToggleDesktop}
            className="flex h-8 w-8 items-center justify-center rounded-lg bg-black/5 text-[#6e6e73] transition-all duration-300 hover:bg-black/10 hover:text-[#111]"
          >
            <ChevronRight size={18} />
          </button>
        </div>
      </div>

      {/* Main nav */}
      <nav className="flex w-full flex-col gap-1">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = isActive(item);
          return (
            <Link
              key={item.href}
              href={item.href as never}
              onClick={onToggleMobile}
              className={[
                "relative flex items-center gap-3 rounded-xl transition-colors",
                "w-full justify-start px-4 py-2.5",
                desktopCollapsed && "lg:h-12 lg:w-12 lg:justify-center lg:px-0 lg:py-0",
                active
                  ? "bg-white font-semibold text-[#111]"
                  : "text-[#6e6e73] hover:bg-white/60 hover:text-[#111]",
              ]
                .filter(Boolean)
                .join(" ")}
            >
              {active && (
                <div className="bg-primary absolute top-1/2 left-0 h-6 w-1 -translate-y-1/2 rounded-r-full" />
              )}
              <Icon size={20} className="shrink-0" />
              <span
                className={["text-sm", desktopCollapsed && "lg:hidden"].filter(Boolean).join(" ")}
              >
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>

      <div className="flex-1" />

      {/* Bottom nav + logout */}
      <div className="mt-4 flex w-full flex-col gap-1">
        {bottomNavItems.map((item) => {
          const Icon = item.icon;
          const active = isActive(item);
          return (
            <Link
              key={item.href}
              href={item.href as never}
              onClick={onToggleMobile}
              className={[
                "relative flex items-center gap-3 rounded-xl transition-colors",
                "w-full justify-start px-4 py-2.5",
                desktopCollapsed && "lg:h-12 lg:w-12 lg:justify-center lg:px-0 lg:py-0",
                active
                  ? "bg-white font-semibold text-[#111]"
                  : "text-[#6e6e73] hover:bg-white/60 hover:text-[#111]",
              ]
                .filter(Boolean)
                .join(" ")}
            >
              {active && (
                <div className="bg-primary absolute top-1/2 left-0 h-6 w-1 -translate-y-1/2 rounded-r-full" />
              )}
              <Icon size={20} className="shrink-0" />
              <span
                className={["text-sm", desktopCollapsed && "lg:hidden"].filter(Boolean).join(" ")}
              >
                {item.label}
              </span>
            </Link>
          );
        })}

        <button
          onClick={onLogout}
          className={[
            "flex items-center gap-3 rounded-xl transition-colors",
            "w-full justify-start px-4 py-2.5",
            desktopCollapsed && "lg:h-12 lg:w-12 lg:justify-center lg:px-0 lg:py-0",
            "text-[#6e6e73] hover:bg-red-500/10 hover:text-red-600",
          ]
            .filter(Boolean)
            .join(" ")}
        >
          <LogOut size={20} className="shrink-0" />
          <span className={["text-sm", desktopCollapsed && "lg:hidden"].filter(Boolean).join(" ")}>
            Log Out
          </span>
        </button>
      </div>
    </aside>
  );
}
