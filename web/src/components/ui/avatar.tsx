import * as React from "react";
import Image from "next/image";
import { cn } from "@/lib/utils";

interface AvatarProps extends React.HTMLAttributes<HTMLDivElement> {
  src?: string;
  alt?: string;
  fallback?: string;
  size?: "sm" | "md" | "lg" | "xl";
}

const sizeClasses = {
  sm: "h-8 w-8 text-xs",
  md: "h-10 w-10 text-sm",
  lg: "h-12 w-12 text-base",
  xl: "h-16 w-16 text-lg",
};

const sizePx = {
  sm: 32,
  md: 40,
  lg: 48,
  xl: 64,
};

const Avatar = React.forwardRef<HTMLDivElement, AvatarProps>(
  ({ className, src, alt, fallback, size = "md", ...props }, ref) => {
    const [imageError, setImageError] = React.useState(false);

    const initials = fallback
      ? fallback
          .split(" ")
          .map((n) => n[0])
          .join("")
          .toUpperCase()
          .slice(0, 2)
      : "?";

    return (
      <div
        ref={ref}
        className={cn(
          "bg-muted relative flex shrink-0 items-center justify-center overflow-hidden rounded-full",
          sizeClasses[size],
          className,
        )}
        {...props}
      >
        {src && !imageError ? (
          <Image
            src={src}
            alt={alt || "Avatar"}
            width={sizePx[size]}
            height={sizePx[size]}
            className="aspect-square h-full w-full object-cover"
            onError={() => setImageError(true)}
          />
        ) : (
          <span className="text-muted-foreground font-medium">{initials}</span>
        )}
      </div>
    );
  },
);
Avatar.displayName = "Avatar";

export { Avatar };
