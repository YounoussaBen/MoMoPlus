import { Clock, type LucideIcon } from "lucide-react";

interface ComingSoonPageProps {
  title: string;
  description: string;
  icon?: LucideIcon;
}

export function ComingSoonPage({ title, description, icon: Icon = Clock }: ComingSoonPageProps) {
  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <div className="max-w-md text-center">
        <div className="bg-muted mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-2xl">
          <Icon size={28} className="text-muted-foreground" />
        </div>
        <div className="bg-muted text-muted-foreground mb-4 inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium">
          <span className="bg-primary h-1.5 w-1.5 rounded-full" />
          Coming Soon
        </div>
        <h2 className="text-foreground mb-3 text-2xl font-bold">{title}</h2>
        <p className="text-muted-foreground text-sm leading-relaxed">{description}</p>
      </div>
    </div>
  );
}
