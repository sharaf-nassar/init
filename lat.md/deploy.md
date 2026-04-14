# Deployment

Production deployment via Terraform to Oracle Cloud free tier, plus scaffolding scripts for new projects.

## Cloud Deployment

Terraform provisions a single Oracle Cloud ARM A1 VM running the full stack: Next.js (standalone) + PostgreSQL via Docker Compose, with Caddy for automatic HTTPS.

### Architecture

Caddy (systemd) terminates TLS via Let's Encrypt and reverse-proxies to `localhost:3000`. Docker Compose runs `web` and `db` services.

Internet traffic hits the OCI Security List (ports 22/80/443), then the VM. The `web` service runs a Next.js standalone build from `Dockerfile.prod`; `db` is Postgres 16 with a named volume. Code is baked into the image at build time — no bind mounts in production.

### Terraform Structure

All infrastructure code lives in `terraform/`. Terraform manages infra only — application deploys go through `scripts/deploy.sh`.

- `main.tf` — Provider config (`oracle/oci`, API key auth)
- `variables.tf` — OCI auth, compute shape, app secrets, network CIDRs
- `outputs.tf` — Public IP, SSH command, deploy command, app URL
- `network.tf` — VCN, internet gateway, route table, public subnet, security list
- `compute.tf` — A1.Flex instance, Ubuntu 24.04 image lookup, cloud-init
- `templates/cloud-init.yml.tftpl` — First-boot automation (Docker, Caddy, clone, build, start)

Run `terraform init && terraform apply` from `terraform/`. Sensitive values (passwords, keys) go in `terraform.tfvars` (gitignored) — see `terraform.tfvars.example` for the template.

### Cloud-Init Bootstrap

First-boot automation that produces a fully working deployment with zero manual steps.

Installs Docker Engine + Caddy from official repos, opens iptables ports 80/443, clones the repo via SSH deploy key, writes the `.env` file, builds containers, runs database migrations, and starts all services.

### Deploy Script

`scripts/deploy.sh` deploys code changes to the VM with a single command.

Pulls latest code, rebuilds containers (baking new code into the image), runs Prisma migrations via the `migrate` service, restarts services, and waits for the `/api/health` endpoint to pass.

### Production Docker

`Dockerfile.prod` is a 3-stage build: deps, builder, runner. `docker-compose.prod.yml` defines three services.

The `deps` stage installs all packages; `builder` runs `next build` with standalone output; `runner` is a minimal Alpine image with just the standalone server (~150 MB). Compose services: `db` (Postgres), `migrate` (runs `prisma migrate deploy` using the builder target, gated by `profiles: ["tools"]`), and `web` (standalone runner). Log rotation is configured on all services.

### Free Tier Limits

Oracle Cloud Always Free ARM A1.Flex: up to 4 OCPUs / 24 GB RAM, 200 GB storage, 10 TB/month egress.

Default config uses 2 OCPUs / 12 GB / 100 GB — leaving room for a second instance. Idle instances with <20% CPU/network/memory over 7 days may be reclaimed; upgrading to Pay-As-You-Go ($0 cost) disables reclamation.

### TLS

Caddy provides automatic HTTPS via Let's Encrypt when a domain is configured; plain HTTP on port 80 otherwise.

The `domain` Terraform variable is optional. When set, Caddy provisions a Let's Encrypt certificate automatically — an A/AAAA DNS record must point to the VM's public IP first. When empty, Caddy serves plain HTTP on port 80, useful for testing before DNS is ready. OCI does not offer managed public TLS certificates on the free tier.

## Scaffolding

Bootstrap script for scaffolding new projects from this template.

### Project Bootstrap

`scripts/create-project.sh` scaffolds a new project from this template with a choice of full-stack or frontend-only mode.

Accepts `<project-name>` (validated: alphanumeric + hyphen/underscore, starts with letter) and optional `--mode full|frontend` (prompted interactively if omitted), `--template REPO` (GitHub via degit), `--web-port`, `--db-port`. Uses `rsync` to copy template files, excluding `node_modules`, `.next`, `.git`, `.env`, `.claude`, and `src/generated`. Tailors `package.json` name, updates `README.md` and `CLAUDE.md` with project-specific values, generates `AUTH_SECRET` via `openssl rand -base64 32` (full mode), and initializes a fresh git repo with an initial commit. Port availability is checked via `ss` (with `lsof` fallback): default ports that are in use are replaced with the next available port in the prompt, and any chosen port that is in use triggers a warning with confirmation (or a hard failure in non-interactive mode). Full-mode custom ports are persisted via generated `.env.example` `APP_PORT` / `DB_PORT` entries so Docker Compose can keep its env-driven port mappings, and shell text edits use backup-suffix `sed` invocations for GNU/BSD portability. Prerequisites: Node.js 24+, npm, git, rsync.

#### Frontend Mode

`--mode frontend` strips all backend components and produces a clean Next.js + Tailwind CSS + shadcn/ui project.

Delegates to `scripts/strip-backend.sh` which removes `src/server/`, `src/trpc/`, `prisma/`, `src/middleware.ts`, `src/lib/logger.ts`, `src/app/api/`, and backend-coupled components (`create-post-form.tsx`, `post-list.tsx`). Replaces `page.tsx`, `layout.tsx`, `env.js`, `docker-compose.yml`, `.env.example`, and `Dockerfile.dev` with frontend-only templates from `scripts/templates/frontend/`. Strips backend dependencies and scripts from `package.json`, updates lint/format commands to drop the `scripts/` path, and simplifies `README.md` and `CLAUDE.md`. The generated project runs with `npm install && npm run dev` — no database or auth setup required.
