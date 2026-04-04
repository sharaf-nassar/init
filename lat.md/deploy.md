# Deploy and Scaffolding

Self-contained CLI tools for deploying to Vercel + Neon and scaffolding new projects from this template.

## Cloud Deploy

`npm run deploy:cloud` provisions infrastructure and deploys without Git integration. Implemented in `scripts/cloud/deploy.mjs`.

The deploy flow: validate local project structure (preflight), check Vercel CLI is installed, resolve and persist a Vercel API token, find or create a Vercel project, provision a Neon Postgres database if `DATABASE_URL` is missing, generate `AUTH_SECRET`, optionally prompt for GitHub OAuth credentials, then run `vercel deploy --prod`. Supports `--scope` for Vercel teams.

### Config Persistence

Global config stored at `~/.config/init/cloud.json` via `scripts/cloud/config.mjs`.

Stores the Vercel API token with file permissions `0o600` and directory permissions `0o700`. Uses atomic write pattern (temp file + rename) to prevent partial writes. Token resolution order: `VERCEL_TOKEN` env var, then saved config, then interactive prompt.

### Vercel Integration

All Vercel CLI interaction wrapped in `scripts/cloud/vercel.mjs` with JSON output parsing.

Functions: `assertVercelInstalled`, `validateVercelToken`, `sanitizeProjectName`, `findProject` / `createProject` / `ensureProjectLink`, `listProductionEnv` / `hasEnvKey` / `addEnv`, `ensureNeonResource`, `deployProduction`. Every call passes `--non-interactive --no-color --token` flags. Project link state tracked via `.vercel/project.json` and `.vercel/init-cloud-project.json` for idempotent re-runs.

### Interactive Prompts

TTY input handling in `scripts/cloud/prompts.mjs` for token and credential entry.

`promptLine` for visible input, `promptSecret` for hidden input (raw TTY mode, no echo, handles Ctrl+C and backspace). `generateAuthSecret` produces a cryptographically random base64url string via `crypto.randomBytes(32)`.

## Project Bootstrap

`scripts/create-project.sh` scaffolds a new project from this template with customizable ports and database names.

Accepts `<project-name>` (validated: alphanumeric + hyphen/underscore, starts with letter) and optional `--template REPO` (GitHub via degit), `--web-port`, `--db-port`. Uses `rsync` to copy template files, excluding `node_modules`, `.next`, `.git`, `.env`, `.claude`, and `src/generated`. Tailors `package.json` name, updates `README.md` and `CLAUDE.md` with project-specific values, generates `AUTH_SECRET` via `openssl rand -base64 32`, and initializes a fresh git repo with an initial commit. Prerequisites: Node.js 24+, npm, git, rsync.
