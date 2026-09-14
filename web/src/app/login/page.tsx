"use client";

import { useState, useEffect, useTransition } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { Eye, EyeOff, Loader2 } from "lucide-react";
import { useAuth } from "@/context/auth-context";
import { useTheme } from "@/context/theme-context";
import { useToast } from "@/components/ui/toast";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function LoginPage() {
  const { user, hydrated, login } = useAuth();
  const { resolvedTheme } = useTheme();
  const router = useRouter();
  const [isNavigating, startTransition] = useTransition();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const { success, error } = useToast();
  const logoSrc = resolvedTheme === "dark" ? "/logo-white.png" : "/logo.png";
  const isBusy = submitting || isNavigating;

  useEffect(() => {
    if (hydrated && user && !isBusy) {
      startTransition(() => {
        router.replace("/dashboard");
      });
    }
  }, [hydrated, isBusy, router, startTransition, user]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (isBusy) return;

    setSubmitting(true);

    try {
      await login(email, password);
      success("Welcome back", "You are signed in to the MoMoPlus dashboard.");
      startTransition(() => {
        router.push("/dashboard");
      });
    } catch (err) {
      error(
        "Sign in failed",
        err instanceof Error ? err.message : "Please check your credentials and try again.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="relative flex min-h-screen flex-col lg:flex-row">
      {/* Brand panel */}
      <div className="bg-secondary border-border/60 relative flex items-start overflow-hidden border-b p-8 lg:w-1/2 lg:border-r lg:border-b-0 lg:p-12">
        <div className="bg-primary/12 absolute -top-24 left-0 h-64 w-64 rounded-full blur-3xl" />
        <div className="bg-info/10 absolute right-0 bottom-0 h-48 w-48 rounded-full blur-3xl" />
        <Image
          src={logoSrc}
          alt="MoMoPlus"
          width={300}
          height={300}
          priority
          className="h-40 w-auto object-contain"
        />
      </div>

      {/* Form panel */}
      <div className="bg-card flex flex-1 items-center justify-center p-8 lg:w-1/2 lg:p-12">
        <div className="w-full max-w-sm">
          <h1 className="text-foreground mb-2 text-2xl font-semibold tracking-tight lg:text-3xl">
            Staff Login
          </h1>
          <p className="text-muted-foreground mb-8 text-sm">
            Sign in to the MoMoPlus admin dashboard
          </p>

          <form onSubmit={handleSubmit} className="flex flex-col gap-5" aria-busy={isBusy}>
            <div className="flex flex-col gap-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="admin@momoplus.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoComplete="email"
                disabled={isBusy}
              />
            </div>

            <div className="flex flex-col gap-2">
              <Label htmlFor="password">Password</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  autoComplete="current-password"
                  disabled={isBusy}
                  className="pr-11"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  disabled={isBusy}
                  className="text-muted-foreground hover:text-foreground absolute top-1/2 right-3 -translate-y-1/2 transition-colors disabled:cursor-not-allowed disabled:opacity-50"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            <Button type="submit" size="lg" className="w-full" disabled={isBusy}>
              {isBusy && <Loader2 className="animate-spin" />}
              {isBusy ? "Signing in..." : "Sign In"}
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
}
