# T3 Stack Boilerplate

## Tech Stack

- **Framework**: Next.js 16 (App Router, Turbopack)
- **Language**: TypeScript 5.9 (strict mode, maximum strictness — see Coding Standards)
- **Database**: PostgreSQL 16
- **ORM**: Prisma 7 (driver adapters, `prisma-client` provider)
- **API Layer**: tRPC 11
- **Authentication**: Auth.js v5 (NextAuth) with `@auth/prisma-adapter`
- **Styling**: Tailwind CSS 4
- **Validation**: Zod 4 (top-level validators: `z.url()`, `z.email()`)
- **Linting/Formatting**: Biome (replaces ESLint + Prettier)
- **Git Hooks**: Husky v9 + lint-staged
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

### Linting & Formatting

- **Biome** handles both linting and formatting in a single tool. Configuration is in `biome.json`.
- **Pre-commit hook** runs `lint-staged` which executes `biome check --write` on staged `.ts`, `.tsx`, `.js`, `.jsx` files and `biome format --write` on staged `.json` files. Violations are auto-fixed where possible; unfixable violations block the commit.
- **Pre-push hook** runs `tsc --noEmit` for a full type check before pushing.
- **Available scripts**: `npm run lint` (check only), `npm run lint:fix` (check + autofix), `npm run format` (format only).
- **Key Biome rules enforced**: `noExplicitAny`, `noNonNullAssertion`, `noUnusedImports`, `noUnusedVariables`, `noDefaultExport` (with overrides for Next.js pages/layouts/routes/configs), `noShadowRestrictedNames` (with override for error.tsx).

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

- **Brand colors are defined as Tailwind CSS custom properties** in `src/styles/globals.css` (`--color-brand`, `--color-brand-hover`). Use `text-brand`, `bg-brand`, `bg-brand-hover` etc. instead of hardcoded `hsl()` values.

## Project Structure

```
├── prisma/schema.prisma          # Database schema (User, Account, Session, Post)
├── prisma.config.ts              # Prisma 7 config (dotenv, datasource URL, migrations)
├── src/
│   ├── generated/prisma/         # Generated Prisma client (gitignored)
│   ├── app/
│   │   ├── page.tsx              # Home page (Server Component, auth check, SSR prefetch)
│   │   ├── layout.tsx            # Root layout with TRPCReactProvider
│   │   ├── error.tsx             # Global error boundary
│   │   ├── _components/
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
│   └── styles/globals.css        # Tailwind base styles + brand color theme
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
├── next.config.js                # Next.js config with security headers (CSP, HSTS)
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
| `DATABASE_URL`       | Yes      | PostgreSQL connection string         |
| `AUTH_SECRET`        | Yes      | Auth.js encryption secret (min 32 chars, generate with `openssl rand -base64 32`) |
| `AUTH_GITHUB_ID`     | No*      | GitHub OAuth App Client ID           |
| `AUTH_GITHUB_SECRET` | No*      | GitHub OAuth App Client Secret       |
| `POSTGRES_USER`      | Yes      | PostgreSQL username                  |
| `POSTGRES_PASSWORD`  | Yes      | PostgreSQL password                  |
| `POSTGRES_DB`        | No       | PostgreSQL database name (default: `t3app`) |

\* Only needed if using GitHub OAuth. The Credentials provider works without these for local dev.

All application-specific variables must have a corresponding entry in `src/env.js`. Never access `process.env` directly for app config — use the typed `env` import from `~/env` instead. Exception: framework-level vars (`NODE_ENV`, `VERCEL_URL`, `PORT`) may be accessed directly in framework glue code (e.g., tRPC client URL detection).

## Key Rules

- **All database mutations MUST use tRPC `protectedProcedure`**. Never expose write operations via `publicProcedure`.
- **All queries MUST be paginated**. Use cursor-based pagination with `useInfiniteQuery` on the client (see `post.getAll` and `post-list.tsx` for the pattern).
- **`protectedProcedure` composes from `publicProcedure`**. Any middleware added to `publicProcedure` is automatically inherited.
- **Read-only queries** may use `publicProcedure` when data is not sensitive.
- **Health endpoint** at `/api/health` checks database connectivity.
- **Error boundary** at `src/app/error.tsx` catches unhandled errors and logs them to the console.
- **tRPC errors are logged server-side** in all environments via `onError` in the route handler.

## Useful Commands

```bash
npm run dev          # Start dev server (Turbopack)
npm run build        # Production build
npm run start        # Start production server
npm run typecheck    # TypeScript type checking (runs all strict checks)
npm run lint         # Run Biome linter (check only)
npm run lint:fix     # Run Biome linter (check + autofix)
npm run format       # Run Biome formatter
npx prisma studio    # Visual database browser
npx prisma db push   # Push schema changes to DB (dev only)
npx prisma generate  # Regenerate Prisma client
npm run db:dev       # Create migration (dev)
npm run db:migrate   # Apply migrations (production)
```
