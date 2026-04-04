"use client";

import { useEffect } from "react";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // biome-ignore lint/suspicious/noConsole: error boundary must log to browser console
    console.error("Unhandled error:", error);
  }, [error]);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c] text-white">
      <div className="flex flex-col items-center gap-6">
        <h1 className="text-4xl font-bold">Something went wrong</h1>
        <p className="text-lg text-white/60">An unexpected error occurred.</p>
        {error.digest && <p className="text-sm text-white/40">Error ID: {error.digest}</p>}
        <button
          type="button"
          onClick={reset}
          className="rounded-lg bg-white/10 px-6 py-3 font-semibold transition hover:bg-white/20"
        >
          Try again
        </button>
      </div>
    </main>
  );
}
