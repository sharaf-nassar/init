"use client";

import { ThemeProvider } from "next-themes";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import { Toaster } from "sonner";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
      <NuqsAdapter>{children}</NuqsAdapter>
      <Toaster richColors closeButton position="bottom-right" />
    </ThemeProvider>
  );
}
