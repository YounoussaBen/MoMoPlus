"use client";

import Image from "next/image";
import { useEffect, useState } from "react";

type Feature = {
  image: string;
  imageAlt: string;
  eyebrow: string;
  title: string;
  text: string;
};

type FeatureStoryListProps = {
  features: Feature[];
};

export function FeatureStoryList({ features }: FeatureStoryListProps) {
  const [visibleFeatures, setVisibleFeatures] = useState<boolean[]>(() =>
    features.map(() => false),
  );

  useEffect(() => {
    const featurePanels = document.querySelectorAll<HTMLElement>("[data-feature-story]");
    const observer = new IntersectionObserver(
      (entries) => {
        setVisibleFeatures((current) => {
          const next = [...current];

          entries.forEach((entry) => {
            const index = Number((entry.target as HTMLElement).dataset.featureStory);

            if (!Number.isNaN(index) && entry.isIntersecting) {
              next[index] = true;
            }
          });

          return next;
        });
      },
      { rootMargin: "-12% 0px -12% 0px", threshold: 0.25 },
    );

    featurePanels.forEach((panel) => observer.observe(panel));

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <div className="landing-feature-scroll mt-12">
      {features.map((feature, index) => (
        <article
          className={`landing-feature-story landing-feature-story-${index + 1}`}
          data-feature-story={index}
          data-visible={visibleFeatures[index]}
          key={feature.title}
        >
          <div className="landing-feature-media">
            <Image
              src={feature.image}
              alt={feature.imageAlt}
              width={760}
              height={560}
              className="h-full w-full object-contain"
            />
          </div>
          <div className="landing-feature-copy">
            <p className="text-sm font-semibold tracking-[0.16em] text-[#2f8f52] uppercase">
              {feature.eyebrow}
            </p>
            <h3 className="mt-4 text-3xl leading-tight font-semibold text-[#101828] sm:text-4xl">
              {feature.title}
            </h3>
            <p className="mt-5 max-w-2xl text-base leading-7 text-[#667085]">{feature.text}</p>
          </div>
        </article>
      ))}
    </div>
  );
}
