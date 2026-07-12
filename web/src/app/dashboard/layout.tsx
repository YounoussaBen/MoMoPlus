"use client";

import { AuthGuard } from "@/components/auth-guard";
import { DashboardShell } from "@/components/dashboard/shell";
import { useAuth } from "@/context/auth-context";
import { useTheme } from "@/context/theme-context";
import { LayoutDashboard, Users, UserCog, ArrowLeftRight, Wallet, Settings } from "lucide-react";

const navItems = [
  { icon: LayoutDashboard, label: "Dashboard", href: "/dashboard", exact: true },
  { icon: Users, label: "User Management", href: "/dashboard/users" },
  { icon: UserCog, label: "Agent Management", href: "/dashboard/agents" },
  { icon: Wallet, label: "Get Funds", href: "/dashboard/get-funds" },
  { icon: ArrowLeftRight, label: "Cash Services", href: "/dashboard/cash-services" },
];

const bottomNavItems = [{ icon: Settings, label: "Settings", href: "/dashboard/settings" }];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { user, logout } = useAuth();
  const { resolvedTheme } = useTheme();
  const logoSrc = resolvedTheme === "dark" ? "/logo-white.png" : "/logo.png";

  return (
    <AuthGuard>
      <DashboardShell
        userName={user ? `${user.first_name} ${user.last_name}`.trim() || user.email : ""}
        userEmail={user?.email ?? ""}
        headerSubtitle="Staff Admin Dashboard"
        navItems={navItems}
        bottomNavItems={bottomNavItems}
        logoSrc={logoSrc}
        onLogout={logout}
        headerFlat
      >
        {children}
      </DashboardShell>
    </AuthGuard>
  );
}
