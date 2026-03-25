import * as React from "react";
import { cn } from "@/lib/utils";

interface EmptyStateProps extends React.HTMLAttributes<HTMLDivElement> {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
}

function EmptyState({ className, icon, title, description, action, ...props }: EmptyStateProps) {
  return (
    <div
      className={cn(
        "border-border/60 bg-card/82 flex flex-col items-center justify-center rounded-[28px] border px-4 py-16 text-center backdrop-blur-xl",
        className,
      )}
      {...props}
    >
      {icon && <div className="bg-secondary text-primary mb-4 rounded-2xl p-4">{icon}</div>}
      <h3 className="text-foreground text-lg font-semibold">{title}</h3>
      {description && <p className="text-muted-foreground mt-2 max-w-sm text-sm">{description}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}

export { EmptyState };
