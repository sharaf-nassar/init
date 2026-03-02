#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# create-project.sh — Bootstrap a new project from this T3 Stack template.
#
# Usage:
#   ./scripts/create-project.sh <project-name> [OPTIONS]
#
# Options:
#   --template REPO  GitHub user/repo to clone via degit (optional).
#                    If omitted, copies files from the local template directory.
#   --web-port PORT  Host port for the Next.js dev server (default: 3000)
#   --db-port PORT   Host port for PostgreSQL (default: 5432)
#
# Prerequisites: Node.js 24+, npm, git
# ─────────────────────────────────────────────────────────────────────────────

# ── Configuration ────────────────────────────────────────────────────────────
TEMPLATE_REPO=""

# ── Defaults ─────────────────────────────────────────────────────────────────
WEB_PORT=3000
DB_PORT=5432

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

# ── Parse arguments ──────────────────────────────────────────────────────────
PROJECT_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --template)
      [ $# -lt 2 ] && fail "--template requires a value (e.g. myorg/t3-boilerplate)"
      TEMPLATE_REPO="$2"
      shift 2
      ;;
    --web-port)
      [ $# -lt 2 ] && fail "--web-port requires a value"
      WEB_PORT="$2"
      shift 2
      ;;
    --db-port)
      [ $# -lt 2 ] && fail "--db-port requires a value"
      DB_PORT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 <project-name> [OPTIONS]"
      echo ""
      echo "Creates a new project from the T3 Stack template."
      echo ""
      echo "Options:"
      echo "  --template REPO  GitHub user/repo to clone via degit (optional)."
      echo "                   If omitted, copies from the local template directory."
      echo "  --web-port PORT  Host port for Next.js dev server (default: 3000)"
      echo "  --db-port PORT   Host port for PostgreSQL (default: 5432)"
      exit 0
      ;;
    -*)
      fail "Unknown option: $1. Use --help for usage."
      ;;
    *)
      [ -n "$PROJECT_NAME" ] && fail "Unexpected argument: $1. Project name already set to '${PROJECT_NAME}'."
      PROJECT_NAME="$1"
      shift
      ;;
  esac
done

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: $0 <project-name> [--template REPO] [--web-port PORT] [--db-port PORT]"
  echo ""
  echo "Creates a new project from the T3 Stack template."
  exit 1
fi

# ── Validate inputs ──────────────────────────────────────────────────────────
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
  fail "Invalid project name '${PROJECT_NAME}'. Use alphanumeric characters, hyphens, and underscores. Must start with a letter."
fi

if [ -d "$PROJECT_NAME" ]; then
  fail "Directory '${PROJECT_NAME}' already exists."
fi

if [[ ! "$WEB_PORT" =~ ^[0-9]+$ ]] || [ "$WEB_PORT" -lt 1 ] || [ "$WEB_PORT" -gt 65535 ]; then
  fail "Invalid web port '${WEB_PORT}'. Must be a number between 1 and 65535."
fi

if [[ ! "$DB_PORT" =~ ^[0-9]+$ ]] || [ "$DB_PORT" -lt 1 ] || [ "$DB_PORT" -gt 65535 ]; then
  fail "Invalid database port '${DB_PORT}'. Must be a number between 1 and 65535."
fi

if [ "$WEB_PORT" = "$DB_PORT" ]; then
  fail "Web port and database port cannot be the same (both set to ${WEB_PORT})."
fi

# ── Check prerequisites ─────────────────────────────────────────────────────
info "Checking prerequisites..."

command -v node >/dev/null 2>&1 || fail "Node.js is required but not installed."
command -v npm  >/dev/null 2>&1 || fail "npm is required but not installed."
command -v git  >/dev/null 2>&1 || fail "git is required but not installed."
if [ -z "$TEMPLATE_REPO" ]; then
  command -v rsync >/dev/null 2>&1 || fail "rsync is required for local template copy but not installed."
fi

NODE_MAJOR=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_MAJOR" -lt 24 ]; then
  fail "Node.js 24+ is required (found v$(node --version))."
fi

ok "Node.js $(node --version), npm $(npm --version), git $(git --version | cut -d' ' -f3)"

# ── Resolve template source directory ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Copy or clone template ────────────────────────────────────────────────
if [ -n "$TEMPLATE_REPO" ]; then
  info "Cloning template from ${TEMPLATE_REPO}..."
  npx --yes degit@2.8.4 "$TEMPLATE_REPO" "$PROJECT_NAME"
  ok "Template cloned into ${PROJECT_NAME}/"
else
  info "Copying local template from ${TEMPLATE_DIR}..."
  mkdir -p "$PROJECT_NAME"
  rsync -a \
    --exclude='node_modules' \
    --exclude='.next' \
    --exclude='.git' \
    --include='.env.example' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='src/generated' \
    --exclude='*.tsbuildinfo' \
    --exclude='next-env.d.ts' \
    --exclude='.claude' \
    "$TEMPLATE_DIR/" "$PROJECT_NAME/"
  ok "Template copied into ${PROJECT_NAME}/"
fi

cd "$PROJECT_NAME"

# ── Update package.json name ─────────────────────────────────────────────────
info "Updating package.json..."
node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  pkg.name = '${PROJECT_NAME}';
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"
ok "Set package name to '${PROJECT_NAME}'"

# ── Clean up README for generated project ──────────────────────────────────
info "Tailoring README.md..."
node -e "
  const fs = require('fs');
  let readme = fs.readFileSync('README.md', 'utf8');

  // Replace title with project name
  readme = readme.replace(/^# T3 Stack Boilerplate/, '# ${PROJECT_NAME}');

  // Replace boilerplate description
  readme = readme.replace(
    /Production-ready \[T3 Stack\]\(https:\/\/create\.t3\.gg\/\) boilerplate with strict TypeScript, security hardening, and Docker support\./,
    'Built with the [T3 Stack](https://create.t3.gg/) — strict TypeScript, security hardening, and Docker support.'
  );

  // Remove 'Creating a New Project' section (up to next ## heading)
  readme = readme.replace(/## Creating a New Project\n[\s\S]*?(?=\n## )/,  '');

  // Remove clone steps from Quick Start (Docker)
  readme = readme.replace(
    /# 1\. Clone the repo\ngit clone <repo-url> my-app\ncd my-app\n\n/g,
    ''
  );

  // Remove clone steps from Quick Start (Local)
  readme = readme.replace(
    /# 1\. Clone the repo\ngit clone <repo-url> my-app\ncd my-app\n\n/g,
    ''
  );

  // Renumber Quick Start steps (2->1, 3->2, 4->3, 5->4)
  readme = readme.replace(/# 2\./g, '# 1.');
  readme = readme.replace(/# 3\./g, '# 2.');
  readme = readme.replace(/# 4\./g, '# 3.');
  readme = readme.replace(/# 5\./g, '# 4.');

  // Remove scripts/create-project.sh from Project Structure
  readme = readme.replace(/├── scripts\/create-project\.sh.*\n/, '');

  fs.writeFileSync('README.md', readme);
"
ok "README.md tailored for ${PROJECT_NAME}"

# ── Clean up CLAUDE.md for generated project ───────────────────────────────
info "Tailoring CLAUDE.md..."
node -e "
  const fs = require('fs');
  let claude = fs.readFileSync('CLAUDE.md', 'utf8');

  // Replace title with project name
  claude = claude.replace(/^# T3 Stack Boilerplate/, '# ${PROJECT_NAME}');

  // Remove scripts/ from Project Structure
  claude = claude.replace(/├── scripts\/\n│   └── create-project\.sh.*\n/, '');

  // Update ports if customized
  if ('${WEB_PORT}' !== '3000') {
    claude = claude.replace(/127\.0\.0\.1:3000/g, '127.0.0.1:${WEB_PORT}');
  }
  if ('${DB_PORT}' !== '5432') {
    claude = claude.replace(/127\.0\.0\.1:5432/g, '127.0.0.1:${DB_PORT}');
  }

  fs.writeFileSync('CLAUDE.md', claude);
"
ok "CLAUDE.md tailored for ${PROJECT_NAME}"

# ── Remove template-only files ─────────────────────────────────────────────
rm -rf scripts/
ok "Removed template-only scripts/"

# ── Configure ports ──────────────────────────────────────────────────────────
if [ "$WEB_PORT" != "3000" ] || [ "$DB_PORT" != "5432" ]; then
  info "Configuring custom ports..."

  if [ "$DB_PORT" != "5432" ]; then
    # Update host-facing DB port in docker-compose.yml (keep container port 5432)
    sed -i "s|127.0.0.1:5432:5432|127.0.0.1:${DB_PORT}:5432|" docker-compose.yml
    # Update DATABASE_URL in .env.example to reflect the host port
    sed -i "s|localhost:5432|localhost:${DB_PORT}|" .env.example
    ok "Database host port set to ${DB_PORT}"
  fi

  if [ "$WEB_PORT" != "3000" ]; then
    # Update host-facing web port in docker-compose.yml (keep container port 3000)
    sed -i "s|127.0.0.1:3000:3000|127.0.0.1:${WEB_PORT}:3000|" docker-compose.yml
    ok "Web server host port set to ${WEB_PORT}"
  fi
fi

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
echo "  Ports:"
echo "    Web server:  127.0.0.1:${WEB_PORT}"
echo "    PostgreSQL:  127.0.0.1:${DB_PORT}"
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
