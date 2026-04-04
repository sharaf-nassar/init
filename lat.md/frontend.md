# Frontend

Tailwind CSS 4 with shadcn/ui components, Lucide icons, Sonner toasts, and nuqs URL state.

## Theming

Dark mode is the default. Brand colors defined as HSL values in the Tailwind `@theme` block in `src/styles/globals.css`.

`ThemeProvider` in [[src/app/_components/providers.tsx]] configured with `defaultTheme="dark"` and `enableSystem`. Brand colors: `text-brand` / `bg-brand` / `bg-brand-hover` mapped to `hsl(280, 100%, 70%)` and `hsl(280, 100%, 60%)`. The `@theme` block also sets `--font-sans` to the Geist font variable. Access theme programmatically via `useTheme()` from `next-themes`. `suppressHydrationWarning` on `<html>` prevents next-themes hydration mismatch — do not remove it.

## UI Components

shadcn/ui pre-configured via `components.json` at project root. Components go in `src/components/ui/`.

- Config uses `~/` aliases, `base-nova` style, lucide icons
- The `base-nova` style uses `@base-ui/react` primitives (from MUI) instead of Radix — same API surface as classic shadcn but with Base UI's unstyled component layer
- Install on demand: `npx shadcn@latest add button dialog dropdown-menu` — only what the app uses
- Use `cn()` from `~/lib/utils` for conditional classes — never concatenate manually
- Use `class-variance-authority` (cva) for component variants with size/variant props
- Check shadcn docs before building primitives from scratch
- Installed components are local source code, not dependencies — modify freely

## Icons

Lucide React for all icons. Import individually: `import { ArrowLeft, Loader2 } from "lucide-react"`. Tree-shakes automatically.

Use the `size` prop, not `width`/`height`: `<ArrowLeft size={16} />`. Animate with Tailwind: `<Loader2 className="animate-spin" />`. Do not install other icon libraries (heroicons, react-icons, etc.).

## Notifications

Sonner for all user-facing notifications. `<Toaster>` pre-configured in `src/app/_components/providers.tsx`.

Semantic methods: `toast.success("Saved")`, `toast.error("Failed")`, `toast.info("Note")`, `toast.warning("Careful")`. Show toasts for every tRPC `useMutation` `onSuccess`. Position: `bottom-right` with `richColors` and `closeButton`. Do not add extra `<Toaster>` instances. Never use `window.alert()`.

## URL State

`nuqs` for type-safe URL search params. `NuqsAdapter` pre-configured in `src/app/_components/providers.tsx`.

Use for shareable/bookmarkable state: filters, search, tabs, sort, pagination. Parser required: `useQueryState("q", parseAsString)`, `useQueryState("page", parseAsInteger.withDefault(1))`. Do not use for ephemeral UI state (modals, form inputs, hover) — use `useState` for those.
