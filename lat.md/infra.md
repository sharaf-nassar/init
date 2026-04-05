# Infrastructure

Docker Compose for local development, pino for structured logging, t3-env for environment validation, and runtime conventions.

## Docker

Docker Compose runs PostgreSQL + Next.js dev server with localhost-only ports and container isolation.

- DB: `127.0.0.1:${DB_PORT:-5432}`, web: `127.0.0.1:${APP_PORT:-3000}` — do not expose beyond localhost
- Anonymous volumes for `/app/node_modules` and `/app/.next` isolate container binaries from host — do not remove
- Resource limits: 2 CPUs, 2GB RAM
- Prisma schema and `prisma.config.ts` are copied before `npm ci` so the `postinstall` script (`prisma generate`) succeeds during the build
- Startup runs `prisma db push` only — client generation is handled at build time by `postinstall`
- `Dockerfile.dev` uses `node:24-alpine` — runs as root for bind-mount compatibility (non-root users can't read host-owned files)

## Logging

Structured server-side logging via pino in `src/lib/logger.ts`. Imports `server-only` — build error if used in client code.

Levels: `fatal`, `error`, `warn`, `info`, `debug`, `trace`. Default: `debug` in dev, `info` in prod (override with `LOG_LEVEL`). Always use structured logging: `logger.info({ userId, action: "post.create" }, "Post created")`. `pino-pretty` is a dev dependency loaded via pino transport — not bundled for production. Never use `console.*` on server paths.

## Environment Variables

All app variables validated at startup via `@t3-oss/env-nextjs` in `src/env.js`. Never access `process.env` directly.

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `AUTH_SECRET` | Yes | Auth.js encryption (min 32 chars) |
| `AUTH_DISABLED` | No | Dev-only auth bypass — see [[auth#Development Bypass]] |
| `AUTH_GITHUB_ID` | No* | GitHub OAuth Client ID |
| `AUTH_GITHUB_SECRET` | No* | GitHub OAuth Client Secret |
| `POSTGRES_USER` | Yes | PostgreSQL username |
| `POSTGRES_PASSWORD` | Yes | PostgreSQL password |
| `POSTGRES_DB` | No | DB name (default: `t3app`) |
| `LOG_LEVEL` | No | Pino log level |

\* Only needed for GitHub OAuth. Credentials provider works without them.

Exception for direct `process.env` access: framework-level vars (`NODE_ENV`, `VERCEL_URL`, `PORT`) in framework glue code like tRPC client URL detection.

## Runtime Conventions

Client providers centralized in `src/app/_components/providers.tsx` — add new providers there, not in `layout.tsx`.

Error boundary at `src/app/error.tsx` catches unhandled errors. Custom 404 at `src/app/not-found.tsx`. Loading state at `src/app/loading.tsx` provides root Suspense fallback. Health check at `/api/health` tests database connectivity.

## Package Management

`prisma generate` runs automatically on `npm install` via the `postinstall` script, ensuring the Prisma client stays in sync after dependency changes.

- `packageManager` field pins npm 11.4+ for consistent installs across environments
- Overrides: `hono`, `@hono/node-server`, and `lodash` are pinned to resolve transitive dependency conflicts from `next-auth` beta — review these after next-auth reaches stable
- Node.js 24+ is required (Docker uses `node:24-alpine`, scripts validated against Node 24 APIs)

## Health Check

`/api/health` endpoint in [[src/app/api/health/route.ts]] tests database connectivity with `SELECT 1`.

Returns `{ status: "healthy", timestamp }` (200) or `{ status: "unhealthy", timestamp }` (503). Excluded from middleware route matcher so it never requires auth. Use for Docker healthchecks, load balancer probes, and uptime monitoring.
