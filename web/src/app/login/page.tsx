"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { Eye, EyeOff } from "lucide-react";
import { useAuth } from "@/context/auth-context";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function LoginPage() {
  const { user, loading, login } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!loading && user) {
      router.replace("/dashboard");
    }
  }, [user, loading, router]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setSubmitting(true);

    try {
      await login(email, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading || user) {
    return (
      <div className="flex min-h-screen flex-col lg:flex-row">
        <div className="flex items-start bg-[#e8f5e0] p-8 lg:w-1/2 lg:p-12">
          <div className="h-40 w-40 animate-pulse rounded-xl bg-white/50" />
        </div>
        <div className="flex flex-1 items-center justify-center bg-white p-8 lg:w-1/2 lg:p-12">
          <div className="w-full max-w-sm space-y-6">
            <div className="space-y-2">
              <div className="h-8 w-32 animate-pulse rounded-xl bg-gray-200" />
              <div className="h-4 w-56 animate-pulse rounded-xl bg-gray-100" />
            </div>
            <div className="space-y-4">
              <div className="h-10 w-full animate-pulse rounded-xl bg-gray-100" />
              <div className="h-10 w-full animate-pulse rounded-xl bg-gray-100" />
              <div className="h-10 w-full animate-pulse rounded-xl bg-gray-200" />
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col lg:flex-row">
      {/* Brand panel */}
      <div className="flex items-start bg-[#e8f5e0] p-8 lg:w-1/2 lg:p-12">
        <Image
          src="/logo.png"
          alt="MoMoPlus"
          width={300}
          height={300}
          priority
          className="h-40 w-auto object-contain"
        />
      </div>

      {/* Form panel */}
      <div className="flex flex-1 items-center justify-center bg-white p-8 lg:w-1/2 lg:p-12">
        <div className="w-full max-w-sm">
          <h1 className="text-foreground mb-2 text-2xl font-semibold tracking-tight lg:text-3xl">
            Staff Login
          </h1>
          <p className="text-muted-foreground mb-8 text-sm">
            Sign in to the MoMoPlus admin dashboard
          </p>

          <form onSubmit={handleSubmit} className="flex flex-col gap-5">
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
                  className="pr-11"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="text-muted-foreground hover:text-foreground absolute top-1/2 right-3 -translate-y-1/2 transition-colors"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {error && (
              <p className="bg-destructive/10 text-destructive rounded-xl px-4 py-2.5 text-sm">
                {error}
              </p>
            )}

            <Button type="submit" size="lg" className="w-full" disabled={submitting}>
              {submitting ? "Signing in..." : "Sign In"}
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
}
