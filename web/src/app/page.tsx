import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Download, MapPin, ShieldCheck, Smartphone, Wallet } from "lucide-react";
import { Button } from "@/components/ui/button";

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
    icon: MapPin,
    title: "Find nearby agents",
    text: "Find mobile money agents when you are in an area you do not really know and need service.",
  },
  {
    icon: Wallet,
    title: "24/7 Momo service",
    text: "Access Momo services no matter the day and no matter the time, even when agents are closed.",
  },
  {
    icon: ShieldCheck,
    title: "Tackle your momo emergencies",
    text: "Get help when you have money on you but no digital cash for an important transaction.",
  },
];

const steps = [
  "Create your MomoPlus profile",
  "Verify your wallet and identity",
  "Find agents or request funds nearby",
  "Track every request from start to finish",
];

export default function LandingPage() {
  return (
    <main className="min-h-screen overflow-hidden bg-[#f7faf7] text-[#111827]">
      <header className="mx-auto flex w-full max-w-7xl items-center justify-between px-5 py-5 sm:px-8 lg:px-10">
        <Link href="/" className="flex items-center gap-3" aria-label="MomoPlus home">
          <Image src="/logo.png" alt="MomoPlus" width={150} height={72} className="h-10 w-auto" />
        </Link>
      </header>

      <section className="relative mx-auto grid w-full max-w-7xl items-center gap-12 px-5 pt-8 pb-20 sm:px-8 lg:grid-cols-[0.94fr_1.06fr] lg:px-10 lg:pt-12 lg:pb-28">
        <div className="max-w-2xl">
          <h1 className="max-w-3xl text-5xl leading-[1.02] font-semibold tracking-normal text-[#0f172a] sm:text-6xl lg:text-7xl">
            MomoPlus
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-8 text-[#526070] sm:text-xl">
            The app that fills the gap in the mobile money service system by helping you access Momo
            services 24/7, no matter the day and no matter the time.
          </p>
          <div className="mt-9 flex flex-col gap-3 sm:flex-row">
            <Button
              asChild
              size="lg"
              className="h-14 rounded-2xl px-7 text-base shadow-lg shadow-[#1e5631]/20"
            >
              <a href="/downloads/momoplus.apk" download>
                <Download className="size-5" />
                Download MomoPlus
              </a>
            </Button>
            <Button
              asChild
              size="lg"
              variant="outline"
              className="h-14 rounded-2xl border-[#d7e7d8] bg-white px-7 text-base"
            >
              <Link href="#how-it-works">
                See how it works
                <ArrowRight className="size-5" />
              </Link>
            </Button>
          </div>
          <div className="mt-5 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm text-[#667085]">
            <span className="inline-flex items-center gap-2">
              <Smartphone className="size-4 text-[#1e5631]" />
              Android available now
            </span>
            <span>iOS coming later</span>
          </div>
        </div>

        <div className="landing-showcase" aria-label="MomoPlus app screenshots">
          <div className="landing-showcase-panel" />
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

      <section className="border-y border-[#e2ece3] bg-white/78">
        <div className="mx-auto grid max-w-7xl gap-4 px-5 py-6 sm:grid-cols-3 sm:px-8 lg:px-10">
          {[
            ["24/7 Momo service", "Access mobile money services no matter the day or time."],
            ["Emergency support", "Perform important transactions when agents are closed."],
            ["Nearby matching", "Find an agent when you are in an area you do not really know."],
          ].map(([title, text]) => (
            <div className="rounded-lg border border-[#e2ece3] bg-white p-5 shadow-sm" key={title}>
              <p className="text-sm font-semibold text-[#1e5631]">{title}</p>
              <p className="mt-2 text-sm leading-6 text-[#5f6f64]">{text}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-5 py-20 sm:px-8 lg:px-10">
        <div className="max-w-2xl">
          <p className="text-sm font-semibold tracking-[0.18em] text-[#2f8f52] uppercase">
            Built for everyday transactions
          </p>
          <h2 className="mt-4 text-3xl font-semibold tracking-normal text-[#101828] sm:text-4xl">
            MomoPlus is here when you need mobile money service and the usual options are not
            available.
          </h2>
        </div>
        <div className="mt-10 grid gap-5 md:grid-cols-3">
          {features.map((feature) => (
            <article
              className="rounded-lg border border-[#dfece1] bg-white p-6 shadow-sm"
              key={feature.title}
            >
              <div className="flex size-11 items-center justify-center rounded-lg bg-[#edf8e9] text-[#1e5631]">
                <feature.icon className="size-5" />
              </div>
              <h3 className="mt-6 text-lg font-semibold text-[#101828]">{feature.title}</h3>
              <p className="mt-3 text-sm leading-6 text-[#667085]">{feature.text}</p>
            </article>
          ))}
        </div>
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
          <div className="grid gap-3">
            {steps.map((step, index) => (
              <div
                className="flex items-center gap-4 rounded-lg border border-white/10 bg-white/6 p-4"
                key={step}
              >
                <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-[#66cc3a] text-sm font-semibold text-[#102015]">
                  {index + 1}
                </span>
                <p className="font-medium text-white/92">{step}</p>
              </div>
            ))}
          </div>
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
        <Button asChild size="lg" className="h-14 rounded-2xl px-7 text-base">
          <a href="/downloads/momoplus.apk" download>
            <Download className="size-5" />
            Download MomoPlus
          </a>
        </Button>
      </section>
    </main>
  );
}
