import Image from "next/image";

const modules = [
  {
    title: "Loan Operations",
    description: "Review applications, approvals, and repayment performance.",
  },
  {
    title: "Customer Support",
    description: "Manage borrower profiles, KYC checks, and account interventions.",
  },
  {
    title: "Risk Controls",
    description: "Monitor fraud signals, policy flags, and manual review queues.",
  },
];

export default function Home() {
  return (
    <main className="min-h-screen px-6 py-10 sm:px-8 lg:px-12">
      <div className="rounded-4xl">
        <Image
          src="/logo.png"
          alt="MoMoPlus logo"
          width={160}
          height={160}
          priority
          className="h-24 w-24 object-contain sm:h-28 sm:w-28 lg:h-36 lg:w-36"
        />
      </div>
      <section className="grid gap-4 lg:grid-cols-3">
        {modules.map((module) => (
          <article key={module.title} className="rounded-3xl bg-gray-100 p-6">
            <h2 className="mt-4 text-xl font-semibold text-slate-950">{module.title}</h2>
            <p className="mt-3 text-sm leading-6 text-gray-600">{module.description}</p>
          </article>
        ))}
      </section>
    </main>
  );
}
