import { Loader2 } from "lucide-react";

export default function Loading() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-gradient-to-b from-[#2e026d] to-[#15162c]">
      <Loader2 className="h-8 w-8 animate-spin text-brand" />
    </main>
  );
}
