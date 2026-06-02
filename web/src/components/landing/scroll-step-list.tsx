"use client";

import { useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";

type ScrollStepListProps = {
  steps: string[];
};

export function ScrollStepList({ steps }: ScrollStepListProps) {
  const [scrollDirection, setScrollDirection] = useState<"down" | "up">("down");
  const [visibleSteps, setVisibleSteps] = useState<boolean[]>(() => steps.map(() => false));
  const lastScrollY = useRef(0);

  useEffect(() => {
    lastScrollY.current = window.scrollY;

    const handleScroll = () => {
      const currentScrollY = window.scrollY;
      setScrollDirection(currentScrollY >= lastScrollY.current ? "down" : "up");
      lastScrollY.current = currentScrollY;
    };

    window.addEventListener("scroll", handleScroll, { passive: true });

    return () => {
      window.removeEventListener("scroll", handleScroll);
    };
  }, []);

  useEffect(() => {
    const stepCards = document.querySelectorAll<HTMLElement>("[data-scroll-step]");
    const observer = new IntersectionObserver(
      (entries) => {
        setVisibleSteps((current) => {
          const next = [...current];

          entries.forEach((entry) => {
            const index = Number((entry.target as HTMLElement).dataset.scrollStep);

            if (!Number.isNaN(index)) {
              next[index] = entry.isIntersecting;
            }
          });

          return next;
        });
      },
      { rootMargin: "-12% 0px -12% 0px", threshold: 0.2 },
    );

    stepCards.forEach((card) => observer.observe(card));

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <div className="grid gap-3">
      {steps.map((step, index) => (
        <div
          className="landing-scroll-step flex items-center gap-4 rounded-lg border border-[#dfece1] bg-white/92 p-4 shadow-sm"
          data-direction={scrollDirection}
          data-scroll-step={index}
          data-visible={visibleSteps[index]}
          key={step}
          style={{ "--step-delay": `${index * 90}ms` } as CSSProperties}
        >
          <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-[#7bd957] text-sm font-semibold text-[#102015]">
            {index + 1}
          </span>
          <p className="font-medium text-[#12301d]">{step}</p>
        </div>
      ))}
    </div>
  );
}
