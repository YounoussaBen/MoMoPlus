"use client";

import {
  Check,
  LaptopMinimal,
  LayoutGrid,
  MoonStar,
  Palette,
  Save,
  SunMedium,
  UserRound,
} from "lucide-react";
import { useState } from "react";
import { useAuth } from "@/context/auth-context";
import { useTheme } from "@/context/theme-context";
import {
  DASHBOARD_RANGE_OPTIONS,
  DEFAULT_DASHBOARD_PREFERENCES,
  useDashboardPreferences,
} from "@/hooks/use-dashboard-preferences";
import { useSettingsProfile, useUpdateSettingsProfile } from "@/hooks/use-settings-profile";
import { cn } from "@/lib/utils";
import type { ThemePreference } from "@/lib/theme";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";

const THEME_OPTIONS: Array<{
  value: ThemePreference;
  label: string;
  description: string;
  icon: typeof SunMedium;
}> = [
  {
    value: "light",
    label: "Light",
    description: "Clean workspace with soft contrast",
    icon: SunMedium,
  },
  {
    value: "dark",
    label: "Dark",
    description: "Low-glare workspace for focused review",
    icon: MoonStar,
  },
  {
    value: "system",
    label: "System",
    description: "Follow your device preference automatically",
    icon: LaptopMinimal,
  },
];

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100] as const;

function SettingSection({
  icon: Icon,
  title,
  description,
  children,
}: {
  icon: typeof UserRound;
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <Card className="border-border/60 border">
      <CardHeader className="pb-4">
        <div className="flex items-start gap-3">
          <div className="bg-secondary text-secondary-foreground rounded-2xl p-3">
            <Icon className="size-5" />
          </div>
          <div className="space-y-1">
            <CardTitle className="text-lg">{title}</CardTitle>
            <CardDescription>{description}</CardDescription>
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-6 pt-0">{children}</CardContent>
    </Card>
  );
}

function ReadOnlyField({ label, value }: { label: string; value: string }) {
  return (
    <div className="space-y-2">
      <Label>{label}</Label>
      <div className="border-border/70 bg-muted/45 text-foreground rounded-2xl border border-dashed px-4 py-3.5 text-sm">
        <span className="block min-w-0 truncate">{value || "—"}</span>
      </div>
    </div>
  );
}

function PreferenceToggle({
  value,
  onChange,
}: {
  value: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <div className="bg-muted inline-flex items-center gap-1 rounded-full p-1">
      {[true, false].map((option) => (
        <button
          key={String(option)}
          type="button"
          onClick={() => onChange(option)}
          className={cn(
            "rounded-full px-4 py-2 text-sm font-medium transition-colors",
            value === option
              ? "bg-card text-foreground"
              : "text-muted-foreground hover:text-foreground",
          )}
        >
          {option ? "On" : "Off"}
        </button>
      ))}
    </div>
  );
}

export function SettingsPageView() {
  const { user, updateUser } = useAuth();
  const { theme, resolvedTheme, setTheme } = useTheme();
  const { preferences, updatePreferences, resetPreferences } = useDashboardPreferences();
  const profileQuery = useSettingsProfile();
  const updateProfileMutation = useUpdateSettingsProfile();
  const [formFeedback, setFormFeedback] = useState<{
    type: "success" | "error";
    message: string;
  } | null>(null);

  const profile = profileQuery.data;
  const profileFormKey = `${profile?.id ?? user?.id ?? "staff"}:${profile?.updated_at ?? "pending"}`;

  const handleProfileSave = async (formData: FormData) => {
    const firstName = String(formData.get("first_name") ?? "").trim();
    const lastName = String(formData.get("last_name") ?? "").trim();

    if (!firstName || !lastName) {
      setFormFeedback({
        type: "error",
        message: "First name and last name are required.",
      });
      return;
    }

    try {
      const updatedProfile = await updateProfileMutation.mutateAsync({
        first_name: firstName,
        last_name: lastName,
      });

      updateUser({
        first_name: updatedProfile.first_name,
        last_name: updatedProfile.last_name,
      });
      setFormFeedback({
        type: "success",
        message: "Profile details updated successfully.",
      });
    } catch (error) {
      setFormFeedback({
        type: "error",
        message: error instanceof Error ? error.message : "Unable to update your profile.",
      });
    }
  };

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        <div>
          <h1 className="text-foreground text-3xl font-semibold tracking-tight">Settings</h1>
          <p className="text-muted-foreground mt-2 max-w-3xl text-sm">
            Manage your staff profile, default dashboard behavior, and workspace appearance from one
            place.
          </p>
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.4fr,1fr]">
        <div className="space-y-6">
          <SettingSection
            icon={UserRound}
            title="Profile"
            description="Update the staff identity shown across the dashboard header and records."
          >
            {profileQuery.isLoading ? (
              <div className="space-y-4">
                <Skeleton className="h-20 rounded-2xl" />
                <div className="grid gap-4 md:grid-cols-2">
                  <Skeleton className="h-24 rounded-2xl" />
                  <Skeleton className="h-24 rounded-2xl" />
                  <Skeleton className="h-24 rounded-2xl" />
                  <Skeleton className="h-24 rounded-2xl" />
                </div>
                <Skeleton className="h-11 w-36 rounded-xl" />
              </div>
            ) : (
              <>
                <div className="bg-muted/55 flex flex-col gap-4 rounded-2xl p-4 sm:flex-row sm:items-center">
                  <div className="flex items-center gap-4">
                    <div className="bg-primary text-primary-foreground flex h-14 w-14 items-center justify-center rounded-full text-lg font-semibold">
                      {`${user?.first_name?.[0] ?? ""}${user?.last_name?.[0] ?? ""}` || "S"}
                    </div>
                    <div>
                      <p className="text-foreground text-base font-semibold">
                        {profile?.full_name ||
                          `${user?.first_name ?? ""} ${user?.last_name ?? ""}`.trim() ||
                          user?.email ||
                          "Staff user"}
                      </p>
                      <p className="text-muted-foreground text-sm">
                        {profile?.email ?? user?.email ?? "No email available"}
                      </p>
                    </div>
                  </div>
                </div>

                {profileQuery.error ? (
                  <p className="text-destructive text-sm">
                    {profileQuery.error instanceof Error
                      ? profileQuery.error.message
                      : "Unable to load profile details."}
                  </p>
                ) : null}

                <form
                  key={profileFormKey}
                  className="grid gap-4 md:grid-cols-2"
                  onSubmit={(event) => {
                    event.preventDefault();
                    void handleProfileSave(new FormData(event.currentTarget));
                  }}
                >
                  <div className="space-y-2">
                    <Label htmlFor="first_name">First Name</Label>
                    <Input
                      id="first_name"
                      name="first_name"
                      defaultValue={profile?.first_name ?? user?.first_name ?? ""}
                      placeholder="Enter first name"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="last_name">Last Name</Label>
                    <Input
                      id="last_name"
                      name="last_name"
                      defaultValue={profile?.last_name ?? user?.last_name ?? ""}
                      placeholder="Enter last name"
                    />
                  </div>
                  <div className="md:col-span-2">
                    <ReadOnlyField
                      label="Email Address"
                      value={profile?.email ?? user?.email ?? ""}
                    />
                  </div>

                  <div className="flex flex-col gap-3 sm:flex-row sm:items-center md:col-span-2">
                    {formFeedback ? (
                      <p
                        className={cn(
                          "text-sm",
                          formFeedback.type === "success" ? "text-success" : "text-destructive",
                        )}
                      >
                        {formFeedback.message}
                      </p>
                    ) : null}
                    <Button
                      type="submit"
                      disabled={updateProfileMutation.isPending}
                      className={cn(!formFeedback && "sm:ml-auto")}
                    >
                      <Save className="size-4" />
                      {updateProfileMutation.isPending ? "Saving..." : "Save changes"}
                    </Button>
                  </div>
                </form>
              </>
            )}
          </SettingSection>

          <SettingSection
            icon={LayoutGrid}
            title="Dashboard Defaults"
            description="Define how the admin workspace should open on this browser."
          >
            <div className="space-y-3">
              <div>
                <h3 className="text-foreground text-sm font-medium">Default overview range</h3>
                <p className="text-muted-foreground mt-1 text-sm">
                  Sets the initial date window for the main dashboard charts and KPI cards.
                </p>
              </div>
              <div className="bg-muted inline-flex flex-wrap items-center gap-1 rounded-2xl p-1">
                {DASHBOARD_RANGE_OPTIONS.map((days) => (
                  <button
                    key={days}
                    type="button"
                    onClick={() => updatePreferences({ defaultRangeDays: days })}
                    className={cn(
                      "rounded-xl px-4 py-2 text-sm font-medium transition-colors",
                      preferences.defaultRangeDays === days
                        ? "bg-card text-foreground"
                        : "text-muted-foreground hover:text-foreground",
                    )}
                  >
                    {days} days
                  </button>
                ))}
              </div>
            </div>

            <div className="space-y-3">
              <div>
                <h3 className="text-foreground text-sm font-medium">Default list page size</h3>
                <p className="text-muted-foreground mt-1 text-sm">
                  Applies to users, agents, KYC, get funds, and cash services when no page size is
                  already in the URL.
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                {PAGE_SIZE_OPTIONS.map((size) => (
                  <button
                    key={size}
                    type="button"
                    onClick={() => updatePreferences({ defaultTablePageSize: size })}
                    className={cn(
                      "border-border rounded-xl border px-4 py-2 text-sm font-medium transition-colors",
                      preferences.defaultTablePageSize === size
                        ? "bg-card text-foreground"
                        : "text-muted-foreground hover:text-foreground hover:bg-muted/60",
                    )}
                  >
                    {size} rows
                  </button>
                ))}
              </div>
            </div>

            <div className="bg-muted/45 flex flex-col gap-4 rounded-2xl p-4 lg:flex-row lg:items-center lg:justify-between">
              <div className="space-y-1">
                <h3 className="text-foreground text-sm font-medium">Remember list filters</h3>
                <p className="text-muted-foreground text-sm">
                  Restore search, filters, page, and page size when you return to a list page.
                </p>
              </div>
              <PreferenceToggle
                value={preferences.rememberListFilters}
                onChange={(value) => updatePreferences({ rememberListFilters: value })}
              />
            </div>

            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <p className="text-muted-foreground text-sm">
                Preferences save automatically to this browser.
              </p>
              <Button
                type="button"
                variant="outline"
                onClick={() => resetPreferences()}
                disabled={
                  preferences.defaultRangeDays === DEFAULT_DASHBOARD_PREFERENCES.defaultRangeDays &&
                  preferences.defaultTablePageSize ===
                    DEFAULT_DASHBOARD_PREFERENCES.defaultTablePageSize &&
                  preferences.rememberListFilters ===
                    DEFAULT_DASHBOARD_PREFERENCES.rememberListFilters
                }
              >
                Reset defaults
              </Button>
            </div>
          </SettingSection>
        </div>

        <div className="space-y-6">
          <SettingSection
            icon={Palette}
            title="Appearance"
            description="Choose the interface theme used across the entire admin dashboard."
          >
            <div className="grid gap-3">
              {THEME_OPTIONS.map((option) => {
                const Icon = option.icon;
                const active = theme === option.value;

                return (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => setTheme(option.value)}
                    className={cn(
                      "border-border flex items-center gap-4 rounded-2xl border px-4 py-4 text-left transition-colors",
                      active ? "bg-card" : "hover:bg-muted/55",
                    )}
                  >
                    <div className="bg-secondary text-secondary-foreground rounded-2xl p-3">
                      <Icon className="size-5" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="text-foreground text-sm font-medium">{option.label}</p>
                      <p className="text-muted-foreground mt-1 text-sm">{option.description}</p>
                    </div>
                    {active ? (
                      <div className="text-primary flex items-center gap-2 text-sm font-medium">
                        <Check className="size-4" />
                        Active
                      </div>
                    ) : null}
                  </button>
                );
              })}
            </div>

            <div className="bg-muted/45 rounded-2xl p-4">
              <p className="text-foreground text-sm font-medium">Current theme output</p>
              <p className="text-muted-foreground mt-1 text-sm">
                Preference: <span className="text-foreground">{theme}</span>
              </p>
              <p className="text-muted-foreground mt-1 text-sm">
                Applied theme: <span className="text-foreground">{resolvedTheme}</span>
              </p>
            </div>
          </SettingSection>
        </div>
      </div>
    </div>
  );
}
