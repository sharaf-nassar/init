# T3 Stack Boilerplate

## Tech Stack

- **Framework**: Next.js 16 (App Router, Turbopack)
- **Language**: TypeScript 5.9 (strict mode, maximum strictness — see Coding Standards)
- **Database**: PostgreSQL 16
- **ORM**: Prisma 7 (driver adapters, `prisma-client` provider)
- **API Layer**: tRPC 11
- **Authentication**: Auth.js v5 (NextAuth) with `@auth/prisma-adapter`
- **Styling**: Tailwind CSS 4
- **UI Components**: shadcn/ui (Base Nova style, Radix primitives via `@base-ui/react`)
- **Icons**: Lucide React (tree-shakeable SVG icons)
- **Notifications**: Sonner (toast notifications)
- **Theming**: next-themes (dark/light/system mode switching)
- **Animation**: Motion (framer-motion v12+, `motion/react`)
- **URL State**: nuqs (type-safe URL search params)
- **Logging**: pino + pino-pretty (structured server-side logging)
- **Image Optimization**: sharp (Next.js production image processing)
- **Validation**: Zod 4 (top-level validators: `z.url()`, `z.email()`)
- **Linting/Formatting**: Biome (replaces ESLint + Prettier)
- **Git Hooks**: Husky v9 + lint-staged
- **Bundle Analysis**: @next/bundle-analyzer (`npm run analyze`)
- **Infrastructure**: Docker & Docker Compose

## Coding Standards

These rules are non-negotiable. Every file committed to this repository must comply.

### Code Completeness

- **No placeholders or stubs.** Never write `// ... rest of code`, `// implement later`, `// TODO`, or similar deferred logic. Every function, component, and file must be complete, working, and copy-pasteable.
- **No dead code.** Do not leave commented-out code blocks. If code is removed, delete it entirely.

### Type Safety

This project uses maximum TypeScript strictness (`tsconfig.json`):
`strict`, `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `noUnusedLocals`, `noUnusedParameters`, `exactOptionalPropertyTypes`, `noFallthroughCasesInSwitch`, `noUncheckedIndexedAccess`.

- **`any` is forbidden.** Never use `any` in type annotations, casts, or generics. If the type is truly unknown, use `unknown` with a proper type guard or Zod parse before accessing properties.
- **`@ts-ignore` and `@ts-expect-error` are forbidden.** Fix the underlying type issue instead of suppressing it.
- **Non-null assertions (`!`) are forbidden.** Use explicit guards (`if (!value) throw ...`) or narrowing instead.
- **`as` type casts are forbidden** unless narrowing from a validated source (e.g., after a Zod `.parse()`). Use `typeof` checks, `instanceof`, or discriminated unions instead.
- **`exactOptionalPropertyTypes` is enabled.** Never assign `undefined` to an optional property via a ternary. Use conditional spread: `...(condition && { prop: value })`.

### Input Validation

- **All external inputs must be validated with Zod before processing.** This includes tRPC procedure inputs, form data, URL parameters, API responses, and any data crossing a trust boundary.
- **tRPC mutations already enforce this** via `.input(z.object({...}))`. Never bypass this by accessing raw request data.
- **String inputs must have max length constraints** in both Zod schemas and HTML form attributes.
- **Use Zod 4 top-level validators.** Prefer `z.url()` over `z.string().url()`, `z.email()` over `z.string().email()`. The method forms are deprecated.
- **Use `z.treeifyError()` for error formatting.** The `.flatten()` and `.format()` methods on `ZodError` are deprecated in Zod 4.

### File Organization

- **150-line limit per file.** If a file exceeds 150 lines of logic (excluding imports and types), extract utility functions, sub-components, or modules. Measure logic lines, not total lines.
- **One concern per file.** A file should do one thing well. Do not mix unrelated utilities, components, or route handlers.
- **Path aliases required.** Always import with `~/` (maps to `./src/`). Never use relative paths.

### Immutability

- **Never mutate data in-place.** Always create new objects/arrays instead of mutating existing ones. Use `slice()`, spread operators, or `map()`/`filter()` — never `.pop()`, `.push()`, `.splice()`, or direct property assignment on shared objects.

### Security

- **Never expose secrets to the client.** Database credentials, `AUTH_SECRET`, and any server-only values must never appear in client-side code or be prefixed with `NEXT_PUBLIC_`.
- **All environment variables must be validated at startup** using `@t3-oss/env-nextjs` in `src/env.js`. Adding a new env var requires updating the schema in `env.js` — never access `process.env` directly elsewhere.
- **`AUTH_SECRET` is always required** (min 32 chars). Generate with `openssl rand -base64 32`.
- **`SKIP_ENV_VALIDATION` is blocked in production.** The flag only works when `NODE_ENV !== "production"`.
- **No hardcoded secrets in source code.** All secrets come from `.env` (gitignored). The `docker-compose.yml` uses `${VAR}` references, never literal values for secrets.
- **HTTP security headers** are configured in `next.config.js` (CSP, HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy). Do not remove them.
- **Signout uses POST.** Always use a `<form>` with server action for sign-out, never a GET link.

### Authentication

- **Auth.js v5 only.** This project uses the modern Auth.js v5 API (`NextAuth()` returning `{ auth, handlers, signIn, signOut }`). Never use v4 patterns like `getServerSession()` or `getSession()`.
- **`auth()` is cached** via React `cache()` in `src/server/auth/index.ts`. Always import from `~/server/auth`, not directly from next-auth.
- **Session strategy is JWT.** The `Session` model in Prisma exists for adapter compatibility but is unused at runtime.
- **Credentials provider is dev-only.** It is conditionally registered at the array level and has a defense-in-depth check inside `authorize()`. Email inputs are validated with Zod.
- **`protectedProcedure` checks `user.id`**, not just `user` existence. An empty string `id` is rejected.
- **`AUTH_DISABLED=true` bypasses all auth in development.** When set, `AUTH_SECRET` is not required, a synthetic dev user session is injected everywhere, middleware skips route protection, and Auth.js is never initialized. This is forced `false` in production via three independent guards (env.js transform, middleware inline check, server-only variable).

### Linting & Formatting

- **Biome** handles both linting and formatting in a single tool. Configuration is in `biome.json`.
- **Pre-commit hook** runs `lint-staged` which executes `biome check --write` on staged `.ts`, `.tsx`, `.js`, `.jsx` files and `biome format --write` on staged `.json` files. Violations are auto-fixed where possible; unfixable violations block the commit.
- **Pre-push hook** runs `tsc --noEmit` for a full type check before pushing.
- **Available scripts**: `npm run lint` (check only), `npm run lint:fix` (check + autofix), `npm run format` (format only).
- **Key Biome rules enforced**: `noExplicitAny`, `noNonNullAssertion`, `noUnusedImports`, `noUnusedVariables`, `noDefaultExport` (with overrides for Next.js pages/layouts/routes/configs), `noShadowRestrictedNames` (with override for error.tsx).
- **Formatting conventions**: 2-space indent, 100-char line width, double quotes, semicolons always, trailing commas everywhere.

### Prisma 7

- **Driver adapters are required.** Prisma 7 uses `@prisma/adapter-pg` (PrismaPg) instead of the built-in query engine. The adapter is configured in `src/server/db.ts`.
- **`prisma.config.ts` is required at the project root.** It loads `.env` via `dotenv/config` (Prisma 7 no longer auto-loads `.env`) and configures the datasource URL for CLI commands (migrations, db push).
- **Import `PrismaClient` from `~/generated/prisma/client`**, not from `@prisma/client`. The generated client output is set to `src/generated/prisma/` and is gitignored.
- **The `datasource` block in `schema.prisma` has no `url`.** The connection URL is provided via the driver adapter at runtime and via `prisma.config.ts` for CLI commands.

### Docker

- **Anonymous volumes isolate container binaries.** The `docker-compose.yml` mounts `/app/node_modules` and `/app/.next` as anonymous volumes so the host's `node_modules` never overwrites the container's. Do not remove these volume entries.
- **Both ports are localhost-only.** DB on `127.0.0.1:5432`, web on `127.0.0.1:3000`. Do not change this.
- **Container runs as non-root user** (`appuser`). The Dockerfile creates a dedicated user for security.
- **Resource limits** are configured on the web container (2 CPUs, 2GB RAM).

### Pagination

- **All list queries use cursor-based pagination** with `useInfiniteQuery` on the client. The server returns `{ posts, nextCursor }` using the `take + 1` / `slice` pattern.
- **The SSR prefetch must use `prefetchInfinite`** with the same input shape as the client `useInfiniteQuery`.

### Theming

- **Dark mode is the default.** The `ThemeProvider` in `src/app/_components/providers.tsx` is configured with `defaultTheme="dark"` and `enableSystem`. Class-based dark mode is enabled via `@custom-variant dark` in `globals.css`.
- **Use semantic theme tokens, not hardcoded colors.** Always use `bg-background`, `text-foreground`, `bg-card`, `text-muted-foreground`, `bg-primary`, `text-primary-foreground`, `bg-destructive`, `border-border`, etc. These automatically adapt to light/dark mode. Never hardcode `oklch()` or `hsl()` values directly.
- **Brand colors** (`--color-brand`, `--color-brand-hover`) are defined in the `@theme` block. Use `text-brand`, `bg-brand`, `bg-brand-hover`.
- **Theme tokens use OKLCH color space** (perceptually uniform). Light mode tokens are in `:root`, dark overrides in `.dark`. The `@theme inline` block bridges CSS variables to Tailwind utilities.
- **Programmatic theme access**: Use `useTheme()` from `next-themes` in client components. Returns `{ theme, setTheme, resolvedTheme }`.
- **`suppressHydrationWarning`** is set on `<html>` in layout.tsx to prevent next-themes hydration warnings. Do not remove it.

### UI Components (shadcn/ui)

- **shadcn/ui is pre-configured** via `components.json` at the project root. Components are installed to `src/components/ui/`. The config uses `~/` path aliases, `base-nova` style, and lucide icons.
- **Install components on demand**: `npx shadcn@latest add button dialog dropdown-menu toast`. Only add components the app actually uses — never install the entire library.
- **Use `cn()` from `~/lib/utils` for conditional classes.** Never concatenate class strings manually. Example: `cn("base-class", isActive && "active-class", className)`.
- **Use `class-variance-authority` (cva) for component variants.** This is pre-installed and is the standard pattern for shadcn components with size/variant props.
- **Never build primitive UI from scratch when shadcn has it.** Check the [shadcn/ui docs](https://ui.shadcn.com/docs/components) before building buttons, dialogs, dropdowns, selects, inputs, cards, tables, tooltips, etc.
- **Installed shadcn components are local source code**, not dependencies. Modify them freely in `src/components/ui/` to match project needs.

### Icons

- **Use Lucide React for all icons.** Import individual icons: `import { ArrowLeft, Loader2, Check } from "lucide-react"`. Icons tree-shake automatically — only imported icons are bundled.
- **Use the `size` prop**, not `width`/`height`. Example: `<ArrowLeft size={16} />`.
- **For animated icons**, combine with the `animate-spin` Tailwind class: `<Loader2 className="animate-spin" />`.
- **Do not install other icon libraries** (heroicons, react-icons, etc.). Lucide covers all common needs and is the same icon set shadcn/ui uses.

### Notifications (Toasts)

- **Use `sonner` for all user-facing notifications.** Import: `import { toast } from "sonner"`. The `<Toaster>` is pre-configured in `src/app/_components/providers.tsx`.
- **Use semantic methods**: `toast.success("Saved")`, `toast.error("Failed")`, `toast.info("Note")`, `toast.warning("Careful")`. Never use `window.alert()` or inline error text when a toast is more appropriate.
- **Show toasts for mutations**: Every tRPC `useMutation` should have `onSuccess` with a toast. Error toasts can supplement inline validation but should not replace it for form fields.
- **Toaster position is `bottom-right`** with `richColors` and `closeButton` enabled. Do not add additional `<Toaster>` instances.

### Animation (Motion)

- **Use the `motion` package** (framer-motion v12+) for page transitions, enter/exit animations, and complex micro-interactions. Import from `motion/react`: `import { motion, AnimatePresence } from "motion/react"`.
- **Prefer CSS animations for simple effects.** Use Tailwind classes (`animate-spin`, `transition`, `hover:scale-105`) for hover states, spinners, and simple transitions. Only reach for Motion when you need layout animations, gesture handling, shared layout transitions, or `AnimatePresence` exit animations.
- **The `tw-animate-css` package** provides additional CSS animation utilities for Tailwind. These are available as classes and are used by shadcn components.

### URL State (nuqs)

- **Use `nuqs` for type-safe URL search params.** The `NuqsAdapter` is pre-configured in `src/app/_components/providers.tsx`. Import: `import { useQueryState, parseAsString, parseAsInteger } from "nuqs"`.
- **Use for shareable/bookmarkable state**: filters, search queries, tabs, sort order, pagination page number. If the state should survive a page refresh or be shareable via URL, use nuqs instead of `useState`.
- **Do not use for ephemeral UI state** (modals open/closed, form input values, hover states). Use `useState` for those.
- **Parser functions are required**: `useQueryState("q", parseAsString)`, `useQueryState("page", parseAsInteger.withDefault(1))`.

### Logging

- **Use the `logger` from `~/lib/logger` for all server-side logging.** Never use `console.log`, `console.error`, or `console.warn` in server-side code (API routes, tRPC procedures, server actions, server components). The logger provides structured JSON output in production and pretty-printed colorized output in development.
- **The logger is server-only.** It imports `server-only` and will cause a build error if imported in a client component. This is intentional.
- **Log levels**: `logger.fatal()`, `logger.error()`, `logger.warn()`, `logger.info()`, `logger.debug()`, `logger.trace()`. Default level is `debug` in development and `info` in production. Override with the `LOG_LEVEL` environment variable.
- **Use structured logging.** Pass objects as the first argument: `logger.info({ userId, action: "post.create" }, "Post created")`. This enables log filtering and analysis in production.
- **`pino-pretty` is a dev dependency** loaded via pino's transport mechanism. It is not bundled for production. `serverExternalPackages` in `next.config.js` ensures pino runs natively in Node.js, not through the bundler.

### Middleware

- **Route protection is handled by `src/middleware.ts`.** It checks the `protectedPrefixes` array and redirects unauthenticated users to the sign-in page. Add new protected route prefixes to this array.
- **The middleware uses cookie-based session detection**, not `auth()`. This avoids importing Prisma into Edge Runtime. The cookie check is a fast presence test — full JWT validation happens server-side when `auth()` runs in Server Components or tRPC procedures.
- **Session cookies checked**: `authjs.session-token` (HTTP) and `__Secure-authjs.session-token` (HTTPS). The middleware redirects to `/api/auth/signin` with a `callbackUrl` parameter.
- **The matcher excludes** `_next/static`, `_next/image`, `favicon.ico`, and `/api/health` from middleware processing.

### Bundle Analysis

- **Run `npm run analyze` to generate a bundle size visualization.** This sets `ANALYZE=true` and runs `next build`, producing an interactive treemap of all client and server bundles.
- **Use this before deploying** to catch unexpected bundle size regressions from new dependencies or imports.

## Architecture Flow

**Client → Server request lifecycle:**

1. Client components call `api.post.getAll.useInfiniteQuery()` (from `~/trpc/react`)
2. Request hits `src/app/api/trpc/[trpc]/route.ts` → `fetchRequestHandler`
3. `createTRPCContext` in `src/server/api/trpc.ts` builds context: `{ db, session, headers }`
4. Router in `src/server/api/root.ts` dispatches to the matching procedure in `src/server/api/routers/`
5. `publicProcedure` runs timing middleware; `protectedProcedure` additionally checks `session.user.id`
6. Procedure validates input with Zod, queries `db` (Prisma), returns typed response
7. SuperJSON serializes the response; TanStack Query caches it client-side (30s stale time)

**SSR prefetch flow (Server Components):**

1. `src/app/page.tsx` imports `api` from `~/trpc/server` (RSC caller, not HTTP)
2. Calls `api.post.getAll.prefetchInfinite(...)` — runs server-side, no network hop
3. Wraps children in `<HydrateClient>` to dehydrate prefetched data into the HTML
4. Client-side `useInfiniteQuery` picks up the hydrated data without refetching

**Adding a new feature (common workflow):**

1. **Schema**: Add model to `prisma/schema.prisma`, run `npx prisma db push`
2. **Router**: Create `src/server/api/routers/<name>.ts`, export from `src/server/api/root.ts`
3. **UI components**: Install needed shadcn components with `npx shadcn@latest add <component>`
4. **Client**: Use `api.<name>.<procedure>` hooks in `src/app/_components/`. Use `cn()` for conditional classes, `toast` for notifications, `lucide-react` for icons.
5. **Page**: Server components prefetch via `~/trpc/server`, wrap in `<HydrateClient>`
6. **Route protection**: If the page requires auth, add its prefix to `protectedPrefixes` in `src/middleware.ts`
7. **URL state**: If filters/search/tabs need to be shareable, use `useQueryState` from `nuqs`
8. **Logging**: Use `logger` from `~/lib/logger` for server-side logging in procedures and actions
9. **Env vars**: Add to `src/env.js` schema first, then reference via `env.<VAR>`

## Project Structure

```
├── prisma/schema.prisma          # Database schema (User, Account, Session, Post)
├── prisma.config.ts              # Prisma 7 config (dotenv, datasource URL, migrations)
├── components.json               # shadcn/ui config (aliases, style, icon library)
├── src/
│   ├── generated/prisma/         # Generated Prisma client (gitignored)
│   ├── components/ui/            # shadcn/ui components (installed on demand)
│   ├── lib/
│   │   ├── utils.ts              # cn() utility (clsx + tailwind-merge)
│   │   └── logger.ts             # Structured pino logger (server-only)
│   ├── middleware.ts              # Auth route protection (cookie-based session check)
│   ├── app/
│   │   ├── page.tsx              # Home page (Server Component, auth check, SSR prefetch)
│   │   ├── layout.tsx            # Root layout (Providers + TRPCReactProvider)
│   │   ├── error.tsx             # Global error boundary
│   │   ├── not-found.tsx         # Custom 404 page
│   │   ├── loading.tsx           # Root Suspense loading state
│   │   ├── _components/
│   │   │   ├── providers.tsx         # Client providers (ThemeProvider, NuqsAdapter, Toaster)
│   │   │   ├── create-post-form.tsx  # Post creation form (Client Component)
│   │   │   └── post-list.tsx         # Paginated post list (Client Component)
│   │   └── api/
│   │       ├── auth/[...nextauth]/route.ts  # Auth.js route handler
│   │       ├── health/route.ts              # Health check endpoint
│   │       └── trpc/[trpc]/route.ts         # tRPC route handler
│   ├── server/
│   │   ├── db.ts                 # Prisma client singleton (PrismaPg driver adapter)
│   │   ├── auth/
│   │   │   ├── config.ts         # Auth.js v5 config (GitHub + dev Credentials)
│   │   │   └── index.ts          # Auth exports (auth, handlers, signIn, signOut)
│   │   └── api/
│   │       ├── root.ts           # tRPC app router
│   │       ├── trpc.ts           # tRPC context, publicProcedure, protectedProcedure
│   │       └── routers/
│   │           └── post.ts       # Post router (getAll with pagination, create)
│   ├── trpc/
│   │   ├── react.tsx             # tRPC client-side hooks
│   │   ├── server.ts             # tRPC server-side caller (RSC)
│   │   └── query-client.ts       # TanStack Query client config
│   ├── env.js                    # Environment variable validation (t3-env)
│   └── styles/globals.css        # Tailwind + shadcn theme tokens (OKLCH, light/dark)
├── scripts/
│   └── create-project.sh        # Bootstrap script for new projects
├── .husky/
│   ├── pre-commit               # Runs lint-staged (Biome on staged files)
│   └── pre-push                 # Runs tsc --noEmit
├── .vscode/
│   ├── settings.json            # Biome format-on-save
│   └── extensions.json          # Recommended extensions
├── biome.json                    # Biome linter + formatter config
├── Dockerfile.dev                # Development container (node:24-alpine, non-root user)
├── docker-compose.yml            # Full dev stack (postgres + web, resource limits)
├── next.config.js                # Next.js config (security headers, bundle analyzer, pino)
└── .env                          # Environment variables (gitignored)
```

## Quick Start (Docker)

```bash
# Generate AUTH_SECRET first (required, min 32 chars)
echo "AUTH_SECRET=$(openssl rand -base64 32)" >> .env

# Start the full stack
docker compose up --build
```

This starts:
- **PostgreSQL** on `127.0.0.1:5432` (localhost only, with healthcheck)
- **Next.js dev server** on `127.0.0.1:3000` (with hot-reloading and healthcheck)

The web container automatically runs `prisma generate` and `prisma db push` on startup.

## Quick Start (Local)

```bash
# Start a PostgreSQL instance (or use the Docker db service)
docker compose up db -d

# Install dependencies
npm install

# Push schema to database
npx prisma db push

# Start dev server
npm run dev
```

## Environment Variables

| Variable             | Required | Description                          |
|----------------------|----------|--------------------------------------|
| `AUTH_DISABLED`      | No       | Set to `"true"` to bypass auth in dev (ignored in production) |
| `DATABASE_URL`       | Yes      | PostgreSQL connection string         |
| `AUTH_SECRET`        | Yes      | Auth.js encryption secret (min 32 chars, generate with `openssl rand -base64 32`) |
| `AUTH_GITHUB_ID`     | No*      | GitHub OAuth App Client ID           |
| `AUTH_GITHUB_SECRET` | No*      | GitHub OAuth App Client Secret       |
| `POSTGRES_USER`      | Yes      | PostgreSQL username                  |
| `POSTGRES_PASSWORD`  | Yes      | PostgreSQL password                  |
| `POSTGRES_DB`        | No       | PostgreSQL database name (default: `t3app`) |
| `LOG_LEVEL`          | No       | Pino log level: `fatal`, `error`, `warn`, `info`, `debug`, `trace` (default: `debug` in dev, `info` in prod) |

\* Only needed if using GitHub OAuth. The Credentials provider works without these for local dev.

All application-specific variables must have a corresponding entry in `src/env.js`. Never access `process.env` directly for app config — use the typed `env` import from `~/env` instead. Exception: framework-level vars (`NODE_ENV`, `VERCEL_URL`, `PORT`) may be accessed directly in framework glue code (e.g., tRPC client URL detection).

## Key Rules

- **All database mutations MUST use tRPC `protectedProcedure`**. Never expose write operations via `publicProcedure`.
- **All queries MUST be paginated**. Use cursor-based pagination with `useInfiniteQuery` on the client (see `post.getAll` and `post-list.tsx` for the pattern).
- **`protectedProcedure` composes from `publicProcedure`**. Any middleware added to `publicProcedure` is automatically inherited.
- **Read-only queries** may use `publicProcedure` when data is not sensitive.
- **Health endpoint** at `/api/health` checks database connectivity.
- **Error boundary** at `src/app/error.tsx` catches unhandled errors and logs them to the console.
- **Custom 404** at `src/app/not-found.tsx` renders a branded not-found page with a back-to-home link.
- **Loading state** at `src/app/loading.tsx` provides a root Suspense fallback with a spinner.
- **tRPC errors are logged server-side** in all environments via `onError` in the route handler. Use `logger` from `~/lib/logger` for all new server-side logging.
- **Client providers** are centralized in `src/app/_components/providers.tsx` (ThemeProvider, NuqsAdapter, Toaster). Add new client-side providers here, not in `layout.tsx`.

## Useful Commands

```bash
npm run dev          # Start dev server (Turbopack)
npm run build        # Production build
npm run start        # Start production server
npm run typecheck    # TypeScript type checking (runs all strict checks)
npm run lint         # Run Biome linter (check only)
npm run lint:fix     # Run Biome linter (check + autofix)
npm run format       # Run Biome formatter
npm run analyze      # Bundle size analysis (interactive treemap)
npx prisma studio    # Visual database browser
npx prisma db push   # Push schema changes to DB (dev only)
npx prisma generate  # Regenerate Prisma client
npm run db:dev       # Create migration (dev)
npm run db:migrate   # Apply migrations (production)
npx shadcn@latest add <component>  # Install a shadcn/ui component
```
