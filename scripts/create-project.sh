#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# create-project.sh — Bootstrap a new project from this T3 Stack template.
#
# Usage:
#   ./scripts/create-project.sh <project-name>
#
# Prerequisites: Node.js 24+, npm, git
# ─────────────────────────────────────────────────────────────────────────────

# ── Configuration ────────────────────────────────────────────────────────────
# Replace with your GitHub user/org and repo name after pushing this template.
TEMPLATE_REPO="OWNER/REPO"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✔${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
fail()  { echo -e "${RED}✖${NC}  $1" >&2; exit 1; }

# ── Validate arguments ──────────────────────────────────────────────────────
if [ $# -lt 1 ]; then
  echo "Usage: $0 <project-name>"
  echo ""
  echo "Creates a new project from the T3 Stack template."
  exit 1
fi

PROJECT_NAME="$1"

# Validate project name (alphanumeric, hyphens, underscores only)
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
  fail "Invalid project name '${PROJECT_NAME}'. Use alphanumeric characters, hyphens, and underscores. Must start with a letter."
fi

if [ -d "$PROJECT_NAME" ]; then
  fail "Directory '${PROJECT_NAME}' already exists."
fi

# ── Check prerequisites ─────────────────────────────────────────────────────
info "Checking prerequisites..."

command -v node >/dev/null 2>&1 || fail "Node.js is required but not installed."
command -v npm  >/dev/null 2>&1 || fail "npm is required but not installed."
command -v git  >/dev/null 2>&1 || fail "git is required but not installed."

NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 24 ]; then
  fail "Node.js 24+ is required (found v$(node --version))."
fi

ok "Node.js $(node --version), npm $(npm --version), git $(git --version | cut -d' ' -f3)"

# ── Check template repo is configured ───────────────────────────────────────
if [ "$TEMPLATE_REPO" = "OWNER/REPO" ]; then
  warn "TEMPLATE_REPO is not configured. Update the TEMPLATE_REPO variable in this script."
  warn "Set it to your GitHub user/org and repo name, e.g. 'myorg/t3-boilerplate'."
  fail "Cannot proceed without a configured template repository."
fi

# ── Clone template ───────────────────────────────────────────────────────────
info "Cloning template from ${TEMPLATE_REPO}..."
npx --yes degit@2.8.4 "$TEMPLATE_REPO" "$PROJECT_NAME"
ok "Template cloned into ${PROJECT_NAME}/"

cd "$PROJECT_NAME"

# ── Update package.json name ─────────────────────────────────────────────────
info "Updating package.json..."
# Use node to safely update JSON without jq dependency
node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  pkg.name = '${PROJECT_NAME}';
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"
ok "Set package name to '${PROJECT_NAME}'"

# ── Set up environment ───────────────────────────────────────────────────────
info "Setting up environment variables..."
if [ -f ".env.example" ]; then
  cp .env.example .env
  ok "Copied .env.example → .env"
else
  touch .env
  warn "No .env.example found — created empty .env"
fi

# Generate AUTH_SECRET and replace the placeholder in .env
AUTH_SECRET=$(openssl rand -base64 32)
sed -i "s|^AUTH_SECRET=.*|AUTH_SECRET=\"${AUTH_SECRET}\"|" .env
ok "Generated AUTH_SECRET"

# ── Initialize git ───────────────────────────────────────────────────────────
info "Initializing git repository..."
git init --quiet
ok "Git repository initialized"

# ── Install dependencies ─────────────────────────────────────────────────────
info "Installing dependencies (this may take a moment)..."
npm install
ok "Dependencies installed"

# ── Initial commit ───────────────────────────────────────────────────────────
info "Creating initial commit..."
git add -A
git commit --quiet -m "chore: initialize project from T3 template"
ok "Initial commit created"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Project '${PROJECT_NAME}' is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Next steps:"
echo ""
echo "    cd ${PROJECT_NAME}"
echo ""
echo "    # Start PostgreSQL (Docker)"
echo "    docker compose up db -d"
echo ""
echo "    # Push database schema"
echo "    npx prisma db push"
echo ""
echo "    # Start the dev server"
echo "    npm run dev"
echo ""
echo "  Or start the full stack with Docker:"
echo ""
echo "    docker compose up --build"
echo ""
