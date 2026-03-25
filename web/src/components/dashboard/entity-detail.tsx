"use client";

import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export function EntityDetailHeader({
  title,
  subtitle,
  backHref,
  badges,
}: {
  title: string;
  subtitle: string;
  backHref: string;
  badges?: React.ReactNode;
}) {
  const router = useRouter();

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
      <Button
        variant="ghost"
        size="icon"
        onClick={() => router.push(backHref as never)}
        className="self-start"
      >
        <ArrowLeft size={18} />
      </Button>
      <div className="min-w-0 flex-1">
        <h1 className="text-foreground text-2xl font-bold">{title}</h1>
        <p className="text-muted-foreground text-sm">{subtitle}</p>
      </div>
      {badges ? <div className="flex flex-wrap items-center gap-2">{badges}</div> : null}
    </div>
  );
}

export function DetailMetricCard({
  label,
  value,
  caption,
}: {
  label: string;
  value: string;
  caption?: string;
}) {
  return (
    <Card className="border-border/50 border">
      <CardHeader className="pb-3">
        <p className="text-muted-foreground text-xs font-medium tracking-wide uppercase">{label}</p>
      </CardHeader>
      <CardContent className="space-y-1">
        <CardTitle className="text-xl">{value}</CardTitle>
        {caption ? <p className="text-muted-foreground text-xs">{caption}</p> : null}
      </CardContent>
    </Card>
  );
}

export function EmptyInlineState({
  title,
  description,
  className,
}: {
  title: string;
  description: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "border-border/50 bg-muted/30 rounded-xl border border-dashed px-4 py-6 text-center",
        className,
      )}
    >
      <p className="text-foreground text-sm font-medium">{title}</p>
      <p className="text-muted-foreground mt-1 text-sm">{description}</p>
    </div>
  );
}

export function DetailPageNotFound({
  title,
  description,
  backHref,
}: {
  title: string;
  description: string;
  backHref: string;
}) {
  const router = useRouter();

  return (
    <div className="flex h-64 flex-col items-center justify-center gap-4">
      <div className="text-center">
        <p className="text-foreground text-sm font-medium">{title}</p>
        <p className="text-muted-foreground text-sm">{description}</p>
      </div>
      <Button variant="outline" onClick={() => router.push(backHref as never)}>
        Go back
      </Button>
    </div>
  );
}
