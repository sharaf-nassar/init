import { ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function NotFound() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c] text-white">
      <div className="flex flex-col items-center gap-6 text-center">
        <p className="text-8xl font-black tracking-tighter text-brand">404</p>
        <h1 className="text-2xl font-bold">Page not found</h1>
        <p className="max-w-md text-white/60">
          The page you&apos;re looking for doesn&apos;t exist or has been moved.
        </p>
        <Link
          href="/"
          className="inline-flex items-center gap-2 rounded-full bg-white/10 px-6 py-3 font-semibold transition hover:bg-white/20"
        >
          <ArrowLeft size={16} />
          Back to home
        </Link>
      </div>
    </main>
  );
}
