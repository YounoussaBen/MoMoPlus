"use client";

import { Check, LaptopMinimal, MoonStar, SunMedium } from "lucide-react";
import { useTheme } from "@/context/theme-context";
import type { ThemePreference } from "@/lib/theme";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const THEME_OPTIONS: Array<{
  value: ThemePreference;
  label: string;
  description: string;
  icon: typeof SunMedium;
}> = [
  {
    value: "light",
    label: "Light",
    description: "Bright interface for daytime work",
    icon: SunMedium,
  },
  {
    value: "dark",
    label: "Dark",
    description: "Low-glare interface with deeper contrast",
    icon: MoonStar,
  },
  {
    value: "system",
    label: "System",
    description: "Match your device preference",
    icon: LaptopMinimal,
  },
];

export function ThemeToggle({ compact = false }: { compact?: boolean }) {
  const { theme, resolvedTheme, setTheme } = useTheme();

  const ActiveIcon =
    theme === "system" ? LaptopMinimal : resolvedTheme === "dark" ? MoonStar : SunMedium;
  const activeLabel = THEME_OPTIONS.find((option) => option.value === theme)?.label ?? "System";

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          aria-label="Change appearance"
          variant="outline"
          className={cn(
            "border-border/70 bg-card/80 text-foreground backdrop-blur-xl",
            compact ? "h-10 rounded-full px-3" : "h-11 rounded-full px-3.5",
          )}
        >
          <ActiveIcon size={16} />
          {!compact && <span className="hidden text-sm md:inline">{activeLabel}</span>}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        align="end"
        sideOffset={10}
        className="border-border/70 bg-popover/95 min-w-[240px] rounded-2xl border p-2 backdrop-blur-xl"
      >
        {THEME_OPTIONS.map((option) => {
          const Icon = option.icon;
          const active = option.value === theme;

          return (
            <DropdownMenuItem
              key={option.value}
              onSelect={() => setTheme(option.value)}
              className={cn(
                "focus:bg-accent/80 focus:text-accent-foreground rounded-xl px-3 py-3",
                active && "bg-accent/65",
              )}
            >
              <div className="flex flex-1 items-center gap-3">
                <div className="bg-muted text-muted-foreground flex h-9 w-9 items-center justify-center rounded-full">
                  <Icon size={16} />
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-medium">{option.label}</p>
                  <p className="text-muted-foreground text-xs">{option.description}</p>
                </div>
              </div>
              {active ? <Check size={16} className="text-primary" /> : null}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
