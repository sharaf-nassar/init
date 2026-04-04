# Tech Stack

Next.js 16 App Router boilerplate with TypeScript 5.9 strict mode, tRPC 11, Prisma 7, and Auth.js v5. Bootstrapped from create-t3-app v7.40.0.

## Core Framework

Next.js 16 with React 19 and Turbopack for development. TypeScript runs in maximum strictness — see [[standards#Type Safety]].

## Data Layer

Prisma 7 with `@prisma/adapter-pg` driver adapter. tRPC 11 for the type-safe API layer — see [[data#tRPC Procedures]].

## Authentication

Auth.js v5 with Prisma adapter, JWT sessions, and a development bypass via `AUTH_DISABLED` — see [[auth#Authentication]].

## Frontend Libraries

Tailwind CSS 4, local shadcn/ui components, Lucide icons, Sonner toasts, `next-themes` for dark mode, and `nuqs` for URL state — see [[frontend#Frontend]].

## Tooling

Biome replaces ESLint + Prettier for linting and formatting — see [[standards#Linting and Formatting]]. Husky v9 + lint-staged for git hooks. Docker Compose for local Postgres + app runtime — see [[infra#Docker]].

## Deploy and Scaffolding

Self-contained CLI for deploying to Vercel + Neon, and a bootstrap script for scaffolding new projects from this template — see [[deploy#Deploy and Scaffolding]].
