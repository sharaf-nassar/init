# Authentication

Auth.js v5 with JWT sessions, Prisma adapter, GitHub OAuth, and a development-only credential bypass.

## Auth.js v5 Patterns

This project uses the modern Auth.js v5 API exclusively. Never use v4 patterns.

`NextAuth()` returns `{ auth, handlers, signIn, signOut }`. The `auth()` function is cached via React `cache()` in `src/server/auth/index.ts` — always import from `~/server/auth`, not directly from `next-auth`. Session strategy is JWT; the `Session` Prisma model exists for adapter compatibility but is unused at runtime. Credentials provider is dev-only, conditionally registered with a defense-in-depth check in `authorize()`. Email inputs are validated with Zod (`z.email().max(254)`).

The `session` callback in [[src/server/auth/config.ts#authConfig]] extracts `token.sub` (the JWT subject claim) into `session.user.id`. It throws if `sub` is missing, failing loud rather than silently producing a session without an ID. The `Session` interface is augmented via module declaration to include the typed `id: string` field.

## Development Bypass

`AUTH_DISABLED=true` bypasses all auth in development for faster iteration.

When set: `AUTH_SECRET` is not required, a synthetic dev user session is injected everywhere, middleware skips route protection, Auth.js is never initialized. Forced `false` in production via three independent guards (`src/env.js` transform, middleware inline check, server-only variable).

## Route Protection

Middleware at `src/middleware.ts` protects routes using cookie-based session detection, avoiding Prisma in Edge Runtime.

The cookie check is a fast presence test — full JWT validation happens server-side in Server Components and tRPC procedures. Cookies checked: `authjs.session-token` (HTTP), `__Secure-authjs.session-token` (HTTPS). Unauthenticated requests redirect to `/api/auth/signin` with `callbackUrl`. Matcher excludes `_next/static`, `_next/image`, `favicon.ico`, `/api/health`. Add new protected routes to the `protectedPrefixes` array.

## Protected Procedures

All database writes must go through tRPC `protectedProcedure`. See [[data#tRPC Procedures]].

`protectedProcedure` checks `session.user.id` specifically — not just `user` existence. An empty string `id` is rejected. It composes from `publicProcedure`, inheriting any middleware added there. Read-only queries may use `publicProcedure` when data is not sensitive.

## Security Headers

HTTP security headers configured in `next.config.js`: CSP, HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy.

Do not remove them. Sign-out must remain a POST flow using a `<form>` with server action — never a GET link.

## Secrets Management

All app env vars must be declared in `src/env.js` via `@t3-oss/env-nextjs`. See [[infra#Environment Variables]].

Never expose secrets to client code or prefix with `NEXT_PUBLIC_` unless genuinely public. `AUTH_SECRET` is always required in normal operation (min 32 chars). Generate with `openssl rand -base64 32`. `SKIP_ENV_VALIDATION` is blocked when `NODE_ENV === "production"`. No hardcoded secrets in source — all secrets come from `.env` (gitignored). Docker Compose uses `${VAR}` references, never literals for secrets.
