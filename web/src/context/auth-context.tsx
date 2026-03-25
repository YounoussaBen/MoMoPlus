"use client";

import { createContext, useContext, useSyncExternalStore, useCallback } from "react";
import { useRouter } from "next/navigation";
import { container } from "@/di/container";
import { queryClient } from "@/di/query-client";
import type { StaffUser } from "@/lib/types";

// ─── localStorage-backed store ───────────────────────────────────────────────

type Listener = () => void;
type AuthSnapshot = { user: StaffUser | null; token: string | null };

const listeners = new Set<Listener>();
let cachedSnapshot: AuthSnapshot = { user: null, token: null };
let cachedRaw: string | null = null;

function getSnapshot(): AuthSnapshot {
  const raw = localStorage.getItem("staff_user");
  const token = localStorage.getItem("access_token");
  // Return cached object if raw hasn't changed (referential stability)
  if (raw === cachedRaw && token === cachedSnapshot.token) return cachedSnapshot;
  cachedRaw = raw;
  if (raw && token) {
    try {
      cachedSnapshot = { user: JSON.parse(raw), token };
      return cachedSnapshot;
    } catch {
      localStorage.removeItem("staff_user");
      localStorage.removeItem("access_token");
    }
  }
  cachedSnapshot = { user: null, token: null };
  return cachedSnapshot;
}

const serverSnapshot: AuthSnapshot = { user: null, token: null };
const getServerSnapshot = () => serverSnapshot;

function subscribe(listener: Listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function emitChange() {
  // Bust cache so next getSnapshot reads fresh data
  cachedRaw = null;
  listeners.forEach((l) => l());
}

// ─── Context ─────────────────────────────────────────────────────────────────

interface AuthContextValue {
  user: StaffUser | null;
  hydrated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const snapshot = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
  const hydrated = useSyncExternalStore(
    subscribe,
    () => true,
    () => false,
  );
  const { user } = snapshot;
  const router = useRouter();

  const login = useCallback(async (email: string, password: string) => {
    const data = await container.authService.login(email, password);

    localStorage.setItem("access_token", data.access);
    localStorage.setItem("staff_user", JSON.stringify(data.user));
    queryClient.clear();
    emitChange();
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem("access_token");
    localStorage.removeItem("staff_user");
    queryClient.clear();
    emitChange();
    router.push("/login");
  }, [router]);

  return (
    <AuthContext.Provider value={{ user, hydrated, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
