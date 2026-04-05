# T3 Stack Boilerplate

Production-ready [T3 Stack](https://create.t3.gg/) boilerplate with strict TypeScript, security hardening, and Docker support.

## Creating a New Project

Use the bootstrap script to scaffold a new project from the local template:

```bash
./scripts/create-project.sh my-new-project
cd my-new-project
docker compose up --build
```

To clone from a remote GitHub repo instead:

```bash
./scripts/create-project.sh my-new-project --template myorg/t3-boilerplate
```

For a frontend-only project (no database, auth, or API layer):

```bash
./scripts/create-project.sh my-new-project --mode frontend
```

If `--mode` is omitted, the script prompts you to choose. Use `--mode full` (the default) for the complete T3 Stack.

Custom ports can be specified if the defaults (3000/5432) are already in use:

```bash
./scripts/create-project.sh my-new-project --web-port 3001 --db-port 5433
```

The script copies (or clones) the template, renames the package, configures ports, generates `AUTH_SECRET` (full mode), installs dependencies, and creates an initial git commit.

## Tech Stack

- **Next.js 16** — App Router, Turbopack
- **TypeScript 5.9** — Maximum strictness (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, etc.)
- **Prisma 7** — Driver adapters, generated client
- **tRPC 11** — End-to-end type-safe API
- **Auth.js v5** — GitHub OAuth + dev credentials provider
- **Zod 4** — Input validation with top-level validators
- **Tailwind CSS 4** — Utility-first styling
- **Biome** — Linting + formatting (replaces ESLint + Prettier)
- **Husky + lint-staged** — Pre-commit (Biome) and pre-push (typecheck) hooks
- **Docker** — PostgreSQL 16 + Node 24 LTS dev container

## lat.md (Architecture Docs)

This repo uses [lat.md](https://www.npmjs.com/package/lat.md) to maintain a structured knowledge graph in the `lat.md/` directory. AI agents and developers use it to understand the architecture before making changes.

The `lat.md/` directory is already initialized — you just need the CLI and an API key for semantic search.

### Setup

```bash
# 1. Install the CLI globally
npm i -g lat.md

# 2. Configure an API key for semantic search (OpenAI or Vercel)
#    Pick ONE of these methods:

# Option A: config file (recommended)
mkdir -p ~/.config/lat
echo '{ "llm_key": "sk-..." }' > ~/.config/lat/config.json

# Option B: environment variable
export LAT_LLM_KEY="sk-..."

# Option C: key file
export LAT_LLM_KEY_FILE="/path/to/key-file"

# Option D: helper command that prints the key
export LAT_LLM_KEY_HELPER="op read 'op://Vault/OpenAI/key'"
```

### Usage

```bash
lat search "auth bypass"           # Semantic search across all sections
lat locate "Route Protection"      # Find a section by name
lat section "auth#Development Bypass"  # Show section with refs
lat check                          # Validate all links and code refs
```

## Quick Start (Docker)

```bash
# 1. Clone the repo
git clone <repo-url> my-app
cd my-app
git submodule update --init

# 2. Install dependencies (also sets up git hooks via Husky)
npm install

# 3. Copy environment template and generate AUTH_SECRET
cp .env.example .env
echo "AUTH_SECRET=$(openssl rand -base64 32)" >> .env

# 4. Start the full stack
docker compose up --build
```

This starts PostgreSQL on `127.0.0.1:5432` and the Next.js dev server on `127.0.0.1:3000`. The web container automatically runs `prisma generate` and `prisma db push` on startup.

## Quick Start (Local)

**Prerequisites:** Node.js 24+, npm, a PostgreSQL instance

```bash
# 1. Clone the repo
git clone <repo-url> my-app
cd my-app
git submodule update --init

# 2. Install dependencies
npm install

# 3. Set up environment variables
cp .env.example .env
# Edit .env — set DATABASE_URL to your PostgreSQL connection string
# Generate AUTH_SECRET:
echo "AUTH_SECRET=$(openssl rand -base64 32)" >> .env

# 4. Push database schema
npx prisma db push

# 5. Start the dev server
npm run dev
```

## Cloud Deploy (Vercel + Neon)

This template can deploy directly from a local checkout without GitHub,
GitLab, Bitbucket, or Azure DevOps integration.

Prerequisite:

```bash
npm install -g vercel
```

Deploy the current directory:

```bash
npm run deploy:cloud
```

On first run, the command will:

- prompt for a missing `VERCEL_TOKEN` and save it in user-global config
- create or reuse a Vercel project for the current app
- provision or reuse a Neon Postgres database through the Vercel integration
- create missing production env vars such as `DATABASE_URL` and `AUTH_SECRET`
- offer to configure GitHub OAuth for working production sign-in

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `AUTH_SECRET` | Yes | Auth.js secret (min 32 chars, generate with `openssl rand -base64 32`) |
| `AUTH_GITHUB_ID` | No | GitHub OAuth App Client ID |
| `AUTH_GITHUB_SECRET` | No | GitHub OAuth App Client Secret |
| `POSTGRES_USER` | Yes | PostgreSQL username (used by Docker Compose) |
| `POSTGRES_PASSWORD` | Yes | PostgreSQL password (used by Docker Compose) |
| `POSTGRES_DB` | No | PostgreSQL database name (default: `t3app`) |

GitHub OAuth is optional for local development — the credentials provider works without it.

## Available Commands

```bash
npm run dev          # Start dev server (Turbopack)
npm run build        # Production build
npm run typecheck    # TypeScript type checking
npm run lint         # Biome linter (check only)
npm run lint:fix     # Biome linter (check + autofix)
npm run format       # Biome formatter
npx prisma studio    # Visual database browser
npx prisma db push   # Push schema changes to DB
npx prisma generate  # Regenerate Prisma client
npm run db:dev       # Create migration (dev)
npm run db:migrate   # Apply migrations (production)
```

## Project Structure

```
├── prisma/schema.prisma          # Database schema
├── prisma.config.ts              # Prisma 7 config (dotenv, datasource)
├── src/
│   ├── generated/prisma/         # Generated Prisma client (gitignored)
│   ├── app/
│   │   ├── page.tsx              # Home page (SSR prefetch)
│   │   ├── layout.tsx            # Root layout
│   │   ├── error.tsx             # Error boundary
│   │   ├── _components/          # Client components
│   │   └── api/                  # Route handlers (auth, health, tRPC)
│   ├── server/
│   │   ├── db.ts                 # Prisma client (PrismaPg driver adapter)
│   │   ├── auth/                 # Auth.js v5 config + exports
│   │   └── api/                  # tRPC router, procedures, context
│   ├── trpc/                     # tRPC client hooks + server caller
│   ├── env.js                    # Environment validation (t3-env)
│   └── styles/globals.css        # Tailwind + brand theme
├── scripts/
│   ├── create-project.sh         # Bootstrap script for new projects
│   └── cloud/
│       ├── config.mjs            # User-global credential persistence
│       ├── prompts.mjs           # Interactive prompts and secret generation
│       ├── vercel.mjs            # Vercel project, env, Neon, and deploy helpers
│       └── deploy.mjs            # Single cloud deploy entrypoint
├── biome.json                    # Linter + formatter config
├── Dockerfile.dev                # Dev container (Node 24 LTS)
└── docker-compose.yml            # PostgreSQL + web (resource limits)
```
## License

MIT
