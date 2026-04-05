export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c] text-white">
      <div className="container flex max-w-2xl flex-col items-center gap-6 px-4 py-16 text-center">
        <h1 className="text-5xl font-extrabold tracking-tight sm:text-[5rem]">
          __PROJECT_NAME__
        </h1>
        <p className="text-xl text-white/70">
          Edit{" "}
          <code className="rounded bg-white/10 px-2 py-1 font-mono text-sm text-brand">
            src/app/page.tsx
          </code>{" "}
          to get started.
        </p>
      </div>
    </main>
  );
}
