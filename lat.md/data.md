# Data Layer

Prisma 7 with driver adapters for database access, tRPC 11 for type-safe API procedures, and cursor-based pagination.

## Prisma 7 Setup

Prisma 7 uses `@prisma/adapter-pg` (PrismaPg) instead of the built-in query engine. Adapter configured in `src/server/db.ts`.

- `prisma.config.ts` at project root loads `.env` via `dotenv/config` (Prisma 7 no longer auto-loads `.env`) and configures the datasource URL for CLI commands
- Import `PrismaClient` from `~/generated/prisma/client`, not from `@prisma/client`
- The `datasource` block in `schema.prisma` has no `url` — connection provided via driver adapter at runtime and via `prisma.config.ts` for CLI
- Generated client output is `src/generated/prisma/` (gitignored)
- DB scripts: `npm run db:dev` (create migration), `npm run db:migrate` (apply), `npx prisma db push` (dev push), `npx prisma generate` (regen client)

## Database Schema

Five Prisma models in `prisma/schema.prisma`: one application model and four Auth.js models.

### ID Strategy

Application models use autoincrement integers; identity models use CUIDs.

`Post.id` is `Int @default(autoincrement())` — compact, index-friendly, and naturally ordered for cursor pagination. `User.id` and `Account.id` are `String @default(cuid())` — non-sequential IDs that prevent enumeration attacks on identity records. New application models should follow the same split: use autoincrement for content that benefits from ordered cursors, CUIDs for anything user-facing or security-sensitive.

### Post

Application content model with cursor-friendly pagination indexes.

Fields: `id` (autoincrement PK), `title`, `content`, `createdAt` (default now), `updatedAt` (auto). Belongs to `User` via `authorId` with cascade delete. Indexes: `[authorId]` for author lookups, `[createdAt DESC, id]` for cursor pagination.

### User

Central identity model shared by Auth.js and application logic.

Fields: `id` (CUID PK), `name?`, `email?` (unique), `emailVerified?`, `image?`. Has many `Account`, `Session`, and `Post` records. The `id` field is the value stored in JWT `sub` and injected into `session.user.id`.

### Account

Auth.js OAuth account linking. Stores provider tokens with cascade delete on user removal.

Unique constraint: `[provider, providerAccountId]`. Fields include OAuth token storage (`access_token`, `refresh_token`, `expires_at`, `id_token`, etc.).

### Session and VerificationToken

Auth.js adapter models required by `PrismaAdapter`. `Session` exists for adapter compatibility but is unused at JWT runtime. `VerificationToken` supports email verification flows with a `[identifier, token]` unique constraint.

## tRPC Procedures

Type-safe API layer with public and protected procedure types. Router defined in `src/server/api/root.ts`.

- `publicProcedure`: includes timing middleware, usable for non-sensitive reads — see [[architecture#tRPC Client#Timing Middleware]]
- `protectedProcedure`: additionally checks `session.user.id` — all database writes must use this. See [[auth#Protected Procedures]]
- Context built by `createTRPCContext` in `src/server/api/trpc.ts`: `{ db, session, headers }`
- tRPC errors logged server-side in all environments via `onError` in the route handler — use `logger` from `~/lib/logger`
- `protectedProcedure` composes from `publicProcedure`, inheriting all its middleware

### Post Router

Canonical tRPC router at [[src/server/api/routers/post.ts]] demonstrating the read/write procedure pattern.

`getAll` (public): paginated read with `limit` (1–100, default 20) and optional `cursor`. Returns `{ posts, nextCursor }` — see [[data#Pagination]]. `create` (protected): requires `title` (1–200 chars) and `content` (1–10 000 chars). Match these Zod constraints in HTML form `maxLength` attributes. Add new routers following this pattern and register them in `src/server/api/root.ts`.

## Pagination

All list queries use cursor-based pagination with the `take + 1` / `slice` pattern.

Server returns `{ items, nextCursor }`. Client uses `useInfiniteQuery` from TanStack Query. SSR prefetch must use `prefetchInfinite` with the same input shape as the client hook. See `src/server/api/routers/post.ts` and `src/app/_components/post-list.tsx` for the canonical implementation.
