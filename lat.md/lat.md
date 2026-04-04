This directory defines the high-level concepts, business logic, and architecture of this project using markdown. It is managed by [lat.md](https://www.npmjs.com/package/lat.md) — a tool that anchors source code to these definitions. Install the `lat` command with `npm i -g lat.md` and run `lat --help`.

- [[stack]] — Tech stack overview: Next.js 16, TypeScript 5.9, tRPC 11, Prisma 7, Auth.js v5
- [[standards]] — Runtime requirements, type safety, immutability, file limits, validation, linting
- [[architecture]] — Request lifecycle, tRPC client, timing middleware, SSR prefetch, error handling, feature workflow
- [[auth]] — Auth.js v5 patterns, dev bypass, route protection, security headers, secrets
- [[data]] — Database schema, ID strategy, Prisma 7 driver adapters, tRPC procedures, post router, cursor-based pagination
- [[frontend]] — Theming, shadcn/ui, Lucide icons, Sonner toasts, nuqs URL state
- [[infra]] — Docker, pino logging, environment variables, package management, runtime conventions, health check
- [[deploy]] — Cloud deploy to Vercel + Neon, project bootstrap scaffolding script
