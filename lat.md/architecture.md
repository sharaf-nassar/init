# Architecture

T3 Stack App Router architecture with tRPC for the API layer, Prisma for data access, and server component SSR prefetching.

## Request Lifecycle

Client components call tRPC hooks, which hit the route handler, build context, dispatch to a procedure, validate with Zod, query Prisma, and return via SuperJSON.

1. Client: `api.post.getAll.useInfiniteQuery()` from `~/trpc/react`
2. Handler: `fetchRequestHandler` in `src/app/api/trpc/[trpc]/route.ts`
3. Context: `createTRPCContext` in `src/server/api/trpc.ts` builds `{ db, session, headers }`
4. Router: dispatches via `src/server/api/root.ts` to matching procedure
5. Procedure: `publicProcedure` runs timing middleware; `protectedProcedure` additionally checks auth — see [[auth#Protected Procedures]]
6. Response: Zod validates input, Prisma queries `db`, SuperJSON serializes, TanStack Query caches client-side (30s stale)

## SSR Prefetch Flow

Server Components prefetch data without a network hop using the RSC tRPC caller from `~/trpc/server`.

1. Page imports `api` from `~/trpc/server`
2. Calls `api.post.getAll.prefetchInfinite(...)` — runs server-side, no HTTP
3. Wraps children in `<HydrateClient>` to dehydrate prefetched data into HTML
4. Client `useInfiniteQuery` picks up hydrated data without refetching

## tRPC Client

Dual tRPC callers — a client-side React hook layer and a server-side RSC caller — unified by shared SuperJSON serialization and a 30-second stale time.

### Client Hooks

`src/trpc/react.tsx` exports `api` (React hooks), `TRPCReactProvider`, and type helpers.

The provider wraps `QueryClientProvider` + `api.Provider`, using `httpBatchStreamLink` with SuperJSON. A `loggerLink` logs all requests in development and only errors in production — disable by removing it from the `links` array, not by changing the condition. URL detection: browser origin in the client, `VERCEL_URL` on Vercel, `localhost:PORT` fallback. QueryClient is a browser singleton; server always creates fresh instances.

### Server Caller

`src/trpc/server.ts` provides `api` (RSC caller) and `HydrateClient` for SSR hydration.

Both `createContext` and `getQueryClient` are wrapped in React `cache()` for per-request deduplication. Sets `x-trpc-source: rsc` header. Guarded by `server-only` import.

### Query Client

[[src/trpc/query-client.ts]] configures TanStack QueryClient with `staleTime: 30_000` (prevents immediate SSR refetch), SuperJSON serialize/deserialize for dehydration, and `dehydrate.shouldDehydrateQuery` that includes pending queries for streaming SSR.

### Timing Middleware

`publicProcedure` includes a timing middleware that logs execution duration for every procedure call in development.

Defined in [[src/server/api/trpc.ts#timingMiddleware]]. Runs on all procedures since `protectedProcedure` composes from `publicProcedure`. Only logs when `isDev` is true — zero overhead in production. Output format: `[TRPC] <path> took <ms>ms to execute`.

## Error Handling

Layered error handling from tRPC procedures through React error boundaries.

tRPC procedure errors throw `TRPCError` with standard codes (`UNAUTHORIZED`, `BAD_REQUEST`, etc.). Zod validation failures are formatted via `z.treeifyError()` into `shape.data.zodError`. All tRPC errors logged server-side via `onError` in the route handler. Client mutations surface errors via `mutation.error.message`. React error boundary at [[src/app/error.tsx]] catches unhandled errors and displays the error digest with a retry button. Custom 404 at [[src/app/not-found.tsx]]. Root loading state at [[src/app/loading.tsx]].

## Adding a Feature

Standard workflow for adding new functionality to this template.

1. **Schema**: Add model to `prisma/schema.prisma`, run `npx prisma db push`
2. **Router**: Create `src/server/api/routers/<name>.ts`, export from `src/server/api/root.ts`
3. **UI**: Install shadcn components: `npx shadcn@latest add <component>` — see [[frontend#UI Components]]
4. **Client**: Use `api.<name>.<procedure>` hooks, `cn()` for classes, `toast` for notifications
5. **Page**: Prefetch via `~/trpc/server`, wrap in `<HydrateClient>`
6. **Protection**: Add route prefix to `protectedPrefixes` in `src/middleware.ts` — see [[auth#Route Protection]]
7. **URL state**: Use `useQueryState` from `nuqs` for shareable state — see [[frontend#URL State]]
8. **Logging**: Use `logger` from `~/lib/logger` — see [[infra#Logging]]
9. **Env vars**: Add to `src/env.js` schema first, then `env.<VAR>` — see [[infra#Environment Variables]]

## Project Structure

Key directories and their responsibilities in the template.

```
├── prisma/schema.prisma              # Database schema
├── prisma.config.ts                  # Prisma 7 config (dotenv, datasource)
├── components.json                   # shadcn/ui config
├── src/
│   ├── generated/prisma/             # Generated Prisma client (gitignored)
│   ├── components/ui/                # shadcn/ui components
│   ├── lib/
│   │   ├── utils.ts                  # cn() utility
│   │   └── logger.ts                 # Structured pino logger (server-only)
│   ├── middleware.ts                  # Auth route protection
│   ├── env.js                        # Environment variable validation
│   ├── styles/globals.css            # Tailwind + shadcn theme tokens
│   ├── app/
│   │   ├── page.tsx                  # Home (SSR prefetch)
│   │   ├── layout.tsx                # Root layout
│   │   ├── error.tsx                 # Error boundary
│   │   ├── not-found.tsx             # Custom 404
│   │   ├── loading.tsx               # Root loading state
│   │   ├── _components/              # Client components
│   │   └── api/                      # Route handlers
│   ├── server/
│   │   ├── db.ts                     # Prisma client (PrismaPg adapter)
│   │   ├── auth/                     # Auth.js config + exports
│   │   └── api/                      # tRPC routers + context
│   └── trpc/                         # tRPC client + server callers
├── scripts/                          # Bootstrap and deploy scripts
├── .husky/                           # Git hooks
└── docker-compose.yml                # Local dev stack
```
