# Init Repo Instructions

This file is the Codex-adapted repo contract for `init`. Keep broader agent behavior in higher-priority global instructions, and treat this file as the maintained replacement for repo-specific guidance that previously lived in `CLAUDE.md`.

`init` is a reusable starter template, not an app with product-specific requirements. Favor generic, durable implementations that downstream projects can inherit cleanly.

## Working Style

- Preserve existing patterns before inventing new ones. The canonical examples are `src/server/api/routers/post.ts`, `src/server/api/trpc.ts`, `src/server/auth/config.ts`, `src/app/_components/providers.tsx`, and `src/env.js`.
- Prefer narrow edits over sweeping refactors. If you touch a file that is getting unwieldy, split it along responsibility boundaries rather than growing it further.
- Before relying on library or framework behavior, verify current official docs instead of trusting memory.
- Do not add product branding, business logic, or app-specific assumptions unless the user explicitly asks for them.

## Stack Snapshot

- Next.js 16 App Router with React 19 and TypeScript 5.9 in strict mode
- tRPC 11 for the API layer
- Prisma 7 with `@prisma/adapter-pg` and generated client output under `src/generated/prisma/`
- Auth.js v5 with Prisma adapter and a development bypass via `AUTH_DISABLED`
- Tailwind CSS 4, local shadcn/ui components, Lucide icons, Sonner toasts, Motion, `next-themes`, and `nuqs`
- Biome for linting and formatting, Husky + lint-staged for git hooks
- Docker Compose for local Postgres + app runtime

## Non-Negotiable Code Rules

- No placeholders, stubs, deferred logic markers, or commented-out dead code.
- Keep files focused. Aim for one concern per file and split files before they exceed roughly 150 lines of logic.
- Use `~/` imports, not relative imports.
- Do not use `any`, `@ts-ignore`, `@ts-expect-error`, non-null assertions, or casual `as` casts. Narrow types explicitly or validate first.
- Prefer immutable updates. Do not mutate shared objects or arrays in place.

## Validation and Types

- Validate every trust-boundary input with Zod: tRPC inputs, form data, URL params, and external API responses.
- Add max-length constraints to user-controlled strings in both Zod schemas and HTML form attributes.
- Prefer Zod 4 top-level validators such as `z.email()` and `z.url()`.
- Use `z.treeifyError()` for structured Zod error formatting.
- Keep TypeScript strictness intact. Fix type problems instead of suppressing them.

## Environment and Security

- All app env vars must be declared in `src/env.js`. Do not read `process.env` directly outside framework glue code.
- Never expose secrets to client code or `NEXT_PUBLIC_*` unless the value is genuinely public.
- `AUTH_SECRET` is required in normal operation and must stay server-only.
- `AUTH_DISABLED=true` is a development-only bypass. Keep the dev-bypass guards aligned across env validation, middleware, and server auth code.
- Preserve the security headers configured in `next.config.js`.
- Sign-out must remain a POST flow, not a GET link.

## Auth, API, and Data Access

- Use Auth.js v5 patterns only. Import auth helpers from `src/server/auth/index.ts`, not directly from `next-auth`.
- All database writes must go through tRPC `protectedProcedure`.
- `protectedProcedure` must enforce a real `session.user.id`, not just a truthy `user`.
- Read-only queries may use `publicProcedure` when the data is not sensitive.
- All list endpoints must use cursor-based pagination. Follow the `take + 1` / `slice` pattern used in `src/server/api/routers/post.ts`.
- Client pagination should use `useInfiniteQuery`, and SSR prefetches must use `prefetchInfinite` with the same input shape.
- Middleware route protection stays cookie-based. Do not import Prisma or full auth evaluation into `src/middleware.ts`.
- Add newly protected routes to `src/middleware.ts`.

## Prisma and Database Conventions

- Keep the Prisma 7 adapter setup in `src/server/db.ts`. Do not switch back to the old built-in engine pattern.
- Import Prisma client/types from `~/generated/prisma/client`, not `@prisma/client`.
- Keep datasource CLI configuration in `prisma.config.ts`. Do not reintroduce a `url` field in `schema.prisma`.
- Use the repo scripts for DB workflows when possible: `npm run db:dev`, `npm run db:migrate`, `npm run db:push`, and `npx prisma generate`.

## Frontend Conventions

- Prefer local shadcn/ui primitives from `src/components/ui/` over bespoke primitives when they fit the need.
- Add shadcn components on demand. Do not install the whole library when only one or two primitives are needed.
- Use `cn()` from `src/lib/utils.ts` for conditional classes.
- Use semantic theme tokens from `src/styles/globals.css` instead of hardcoded color values.
- Keep client providers centralized in `src/app/_components/providers.tsx`, not in `layout.tsx`.
- Use Sonner for user-facing mutation feedback.
- Use `nuqs` for shareable URL state, not ephemeral component state.
- Prefer CSS transitions for simple effects; use `motion/react` when layout or presence animation actually requires it.
- Use Lucide icons and the `size` prop.

## Logging and Runtime Behavior

- Use `src/lib/logger.ts` for server-side logging. Do not add `console.*` calls to server paths.
- Keep the health check at `/api/health` lightweight and database-focused.
- Client providers belong in `src/app/_components/providers.tsx`.
- The global error boundary is `src/app/error.tsx`; preserve it as the catch-all UI boundary.

## Docker and Local Runtime

- Keep Docker ports localhost-only.
- Preserve the anonymous volume pattern for `/app/node_modules` and `/app/.next`.
- Keep the container running as a non-root user.

## Verification

- Run the narrowest relevant checks before finishing. For this repo that usually means `npm run typecheck` and `npm run lint`, plus any targeted command needed for the change.
- Do not claim success if you did not run verification.

## Useful Commands

```bash
npm run dev
npm run build
npm run start
npm run typecheck
npm run lint
npm run lint:fix
npm run format
npm run analyze
npm run db:dev
npm run db:migrate
npm run db:push
npx prisma generate
npx prisma studio
```
