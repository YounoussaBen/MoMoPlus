"use client";

import { useState, useEffect } from "react";
import { Sidebar, type NavItem } from "./sidebar";
import { Header } from "./header";

interface DashboardShellProps {
  children: React.ReactNode;
  userName: string;
  userEmail: string;
  headerSubtitle?: string;
  settingsHref?: string;
  navItems: NavItem[];
  bottomNavItems?: NavItem[];
  logoSrc?: string;
  logoCollapsedSrc?: string;
  onLogout: () => void | Promise<void>;
  headerFlat?: boolean;
}

export function DashboardShell({
  children,
  userName,
  userEmail,
  headerSubtitle,
  settingsHref,
  navItems,
  bottomNavItems,
  logoSrc,
  logoCollapsedSrc,
  onLogout,
  headerFlat,
}: DashboardShellProps) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [desktopCollapsed, setDesktopCollapsed] = useState(false);

  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth >= 1024) setMobileOpen(false);
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return (
    <div className="flex min-h-screen">
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/20 lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      <Sidebar
        navItems={navItems}
        bottomNavItems={bottomNavItems}
        logoSrc={logoSrc}
        logoCollapsedSrc={logoCollapsedSrc}
        mobileOpen={mobileOpen}
        desktopCollapsed={desktopCollapsed}
        onToggleMobile={() => setMobileOpen(false)}
        onToggleDesktop={() => setDesktopCollapsed((v) => !v)}
        onLogout={onLogout}
      />

      <div className="flex min-w-0 flex-1 flex-col p-4 md:p-6">
        <Header
          userName={userName}
          userEmail={userEmail}
          subtitle={headerSubtitle}
          settingsHref={settingsHref}
          onToggleSidebar={() => setMobileOpen((v) => !v)}
          onLogout={onLogout}
          flat={headerFlat}
        />
        <main className="flex-1">{children}</main>
      </div>
    </div>
  );
}
