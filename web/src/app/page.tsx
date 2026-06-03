import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  CircleAlert,
  Clock3,
  Compass,
  Download,
  Mail,
  Phone,
  Smartphone,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { FeatureStoryList } from "@/components/landing/feature-story-list";
import { ScrollStepList } from "@/components/landing/scroll-step-list";

const appScreens = [
  {
    src: "/landing/app-home.png",
    alt: "MomoPlus home screen showing cash service activity and quick actions",
    className: "landing-phone-primary",
  },
  {
    src: "/landing/app-discover.png",
    alt: "MomoPlus discover screen showing nearby mobile money agents on a map",
    className: "landing-phone-secondary landing-phone-left",
  },
  {
    src: "/landing/app-wallet-verify.png",
    alt: "MomoPlus wallet verification screen with OTP code input",
    className: "landing-phone-secondary landing-phone-right",
  },
];

const features = [
  {
    image: "/landing/request-digital-cash.png",
    imageAlt: "Digital cash request illustration for urgent mobile money needs",
    eyebrow: "Emergency access",
    title: "Convert cash to MoMo when it cannot wait",
    text: "Start a request when you have physical cash but need digital money for an urgent payment.",
  },
  {
    image: "/landing/nearby-agent.png",
    imageAlt: "Person using MomoPlus to find a nearby mobile money agent",
    eyebrow: "Nearby matching",
    title: "Find agents around you in unfamiliar places",
    text: "Discover nearby mobile money agents and choose the most convenient meetup point.",
  },
];

const steps = [
  "Create your MomoPlus profile",
  "Verify your wallet and identity",
  "Find agents or request funds nearby",
  "Track every request from start to finish",
];

const navLinks = [
  { href: "/", label: "Home" },
  { href: "#features", label: "Features" },
  { href: "#how-it-works", label: "How it works" },
] as const;

const heroBrand = "MomoPlus";

const serviceHighlights = [
  {
    icon: Clock3,
    title: "24/7 Momo service",
    text: "Access mobile money services no matter the day or no matter the time.",
  },
  {
    icon: CircleAlert,
    title: "Emergency transactions",
    text: "Need to pay at night but have no digital cash? MomoPlus is here for you.",
  },
  {
    icon: Compass,
    title: "Unfamiliar locations",
    text: "Need mobile money in a new area? MomoPlus helps you find an agent.",
  },
] as const;

export default function LandingPage() {
  return (
    <main className="landing-page min-h-screen overflow-hidden bg-[#f7faf7] text-[#111827]">
      <header className="mx-auto flex w-full max-w-7xl flex-col gap-4 px-5 py-5 sm:px-8 md:flex-row md:items-center md:justify-between lg:px-10">
        <div className="flex items-center justify-between gap-4">
          <Link href="/" className="flex items-center gap-3" aria-label="MomoPlus home">
            <Image src="/logo.png" alt="MomoPlus" width={150} height={72} className="h-10 w-auto" />
          </Link>
          <div className="flex items-center gap-2 md:hidden">
            <Button
              asChild
              size="sm"
              className="rounded-full px-4 text-white shadow-sm shadow-[#1e5631]/15 hover:text-white [&_svg]:text-white"
            >
              <a
                className="text-white"
                href="/downloads/momoplus.apk"
                style={{ color: "#ffffff" }}
                download
              >
                <Download className="size-4" />
                Download
              </a>
            </Button>
          </div>
        </div>
        <nav className="hidden rounded-full border border-[#d7e7d8] bg-white/88 px-2 py-2 text-sm font-medium text-[#526070] shadow-sm backdrop-blur md:flex">
          {navLinks.map((link) => (
            <Link
              className="rounded-full px-4 py-2 transition-colors hover:bg-[#f0f7f1] hover:text-[#1e5631]"
              href={link.href}
              key={link.href}
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <nav className="mx-auto flex max-w-full justify-center gap-2 overflow-x-auto rounded-full bg-white/72 p-1 text-sm font-medium text-[#526070] shadow-sm shadow-[#1e5631]/5 md:hidden">
          {navLinks.map((link) => (
            <Link
              className="shrink-0 rounded-full px-4 py-2 transition-colors hover:bg-[#f0f7f1] hover:text-[#1e5631]"
              href={link.href}
              key={link.href}
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="hidden items-center gap-2 md:flex">
          <Button
            asChild
            size="sm"
            className="rounded-full px-4 text-white shadow-sm shadow-[#1e5631]/15 hover:text-white [&_svg]:text-white"
          >
            <a
              className="text-white"
              href="/downloads/momoplus.apk"
              style={{ color: "#ffffff" }}
              download
            >
              <Download className="size-4" />
              Download
            </a>
          </Button>
        </div>
      </header>

      <section className="relative mx-auto grid w-full max-w-7xl items-center gap-12 px-5 pt-8 pb-20 sm:px-8 lg:grid-cols-[0.94fr_1.06fr] lg:px-10 lg:pt-12 lg:pb-28">
        <div className="max-w-2xl">
          <h1
            aria-label={heroBrand}
            className="landing-hero-title max-w-3xl text-5xl leading-[1.02] font-semibold tracking-normal text-[#0f172a] sm:text-6xl lg:text-7xl"
          >
            <span className="landing-hero-word" aria-hidden="true">
              {heroBrand.split("").map((letter, index) => (
                <span
                  className="landing-hero-letter"
                  key={`${letter}-${index}`}
                  style={{ animationDelay: `${index * 180 + 240}ms` }}
                >
                  {letter}
                </span>
              ))}
            </span>
          </h1>
          <p className="landing-hero-copy mt-6 max-w-xl text-lg leading-8 text-[#526070] sm:text-xl">
            The app that fills the gap in the mobile money service system.
            <br />
            The app that helps you access Momo services 24/7.
          </p>

          <div className="landing-hero-actions mt-9 flex flex-col gap-3 sm:flex-row">
            <Button
              asChild
              size="lg"
              className="h-14 rounded-2xl px-7 text-base text-white shadow-lg shadow-[#1e5631]/20 hover:text-white [&_svg]:text-white"
            >
              <a
                className="text-white"
                href="/downloads/momoplus.apk"
                style={{ color: "#ffffff" }}
                download
              >
                <Download className="size-5" />
                Download MomoPlus
              </a>
            </Button>
            <Button
              asChild
              size="lg"
              variant="outline"
              className="landing-secondary-cta h-14 rounded-2xl border-[#d7e7d8] bg-white px-7 text-base"
            >
              <Link href="#how-it-works">
                See how it works
                <ArrowRight className="size-5" />
              </Link>
            </Button>
          </div>
          <div className="mt-5 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm text-[#667085]">
            <span className="inline-flex items-center gap-2 rounded-full px-2 py-1 active:bg-[#1e5631] active:text-white active:[&_svg]:text-white">
              <Smartphone className="size-4 text-[#1e5631]" />
              Android available now
            </span>
            <span>iOS coming later</span>
          </div>
        </div>

        <div className="landing-showcase" aria-label="MomoPlus app screenshots">
          {appScreens.map((screen) => (
            <div className={screen.className} key={screen.src}>
              <Image
                src={screen.src}
                alt={screen.alt}
                width={424}
                height={920}
                priority={screen.src.includes("home")}
                className="h-full w-full rounded-4xl object-cover"
              />
            </div>
          ))}
        </div>
      </section>

      <section id="services" className="bg-[#eef7ef]">
        <div className="mx-auto grid max-w-7xl gap-8 px-5 py-10 sm:grid-cols-3 sm:px-8 lg:px-10">
          {serviceHighlights.map(({ icon: Icon, title, text }) => (
            <div className="flex gap-4" key={title}>
              <span className="mt-1 flex size-11 shrink-0 items-center justify-center rounded-full bg-[#d9f1dc] text-[#1e5631]">
                <Icon className="size-5" aria-hidden="true" />
              </span>
              <div>
                <p className="text-base font-semibold text-[#102015]">{title}</p>
                <p className="mt-2 text-sm leading-6 text-[#5f6f64]">{text}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section id="features" className="mx-auto max-w-7xl px-5 py-20 sm:px-8 lg:px-10">
        <div className="max-w-2xl">
          <p className="text-sm font-semibold tracking-[0.18em] text-[#2f8f52] uppercase">
            Built for everyday transactions
          </p>
          <h2 className="mt-4 text-3xl font-semibold tracking-normal text-[#101828] sm:text-4xl">
            Everything you need to access mobile money support when the usual service system leaves
            a gap.
          </h2>
        </div>
        <FeatureStoryList features={features} />
      </section>

      <section id="how-it-works" className="bg-[#102015] py-20 text-white">
        <div className="mx-auto grid max-w-7xl gap-12 px-5 sm:px-8 lg:grid-cols-[0.9fr_1.1fr] lg:px-10">
          <div>
            <p className="text-sm font-semibold tracking-[0.18em] text-[#7bd957] uppercase">
              Simple flow
            </p>
            <h2 className="mt-4 text-3xl font-semibold tracking-normal sm:text-4xl">
              From signup to successful cash service in a few clear steps.
            </h2>
          </div>
          <ScrollStepList steps={steps} />
        </div>
      </section>

      <section className="mx-auto flex max-w-7xl flex-col items-start justify-between gap-8 px-5 py-16 sm:px-8 md:flex-row md:items-center lg:px-10">
        <div>
          <h2 className="text-3xl font-semibold tracking-normal text-[#101828]">
            Ready to try MomoPlus?
          </h2>
          <p className="mt-3 max-w-2xl text-base leading-7 text-[#667085]">
            Download the Android APK now. iOS support will be announced later.
          </p>
        </div>
        <Button
          asChild
          size="lg"
          className="h-14 rounded-2xl px-7 text-base text-white hover:text-white [&_svg]:text-white"
        >
          <a
            className="text-white"
            href="/downloads/momoplus.apk"
            style={{ color: "#ffffff" }}
            download
          >
            <Download className="size-5" />
            Download MomoPlus
          </a>
        </Button>
      </section>

      <footer className="border-t border-[#d7e7d8] bg-white">
        <div className="mx-auto flex max-w-7xl flex-col gap-5 px-5 py-8 text-sm text-[#526070] sm:px-8 md:flex-row md:items-center md:justify-between lg:px-10">
          <div>
            <p className="font-semibold text-[#102015]">Dorina Akosua Anani</p>
            <p className="mt-1">MomoPlus contact</p>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-5">
            <a
              className="inline-flex items-center gap-2 transition-colors hover:text-[#1e5631]"
              href="tel:+233549700076"
            >
              <Phone className="size-4" aria-hidden="true" />
              +233 54 970 0076
            </a>
            <a
              className="inline-flex items-center gap-2 transition-colors hover:text-[#1e5631]"
              href="mailto:ananidorina@gmail.com"
            >
              <Mail className="size-4" aria-hidden="true" />
              ananidorina@gmail.com
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
