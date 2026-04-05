#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# create-project.sh — Bootstrap a new project from this T3 Stack template.
#
# Usage:
#   ./scripts/create-project.sh <project-name> [OPTIONS]
#
# Options:
#   --mode MODE      Project mode: 'full' or 'frontend' (prompted if omitted)
#                    full: Next.js + tRPC + Prisma + Auth.js (default)
#                    frontend: Next.js only (no database, auth, or API layer)
#   --template REPO  GitHub user/repo to clone via degit (optional).
#                    If omitted, copies files from the local template directory.
#   --web-port PORT  Host port for the Next.js dev server (default: 3000)
#   --db-port PORT   Host port for PostgreSQL (default: 5432, full mode only)
#
# Prerequisites: Node.js 24+, npm, git
# ─────────────────────────────────────────────────────────────────────────────

# ── Configuration ────────────────────────────────────────────────────────────
TEMPLATE_REPO=""

# ── Defaults ─────────────────────────────────────────────────────────────────
MODE=""
WEB_PORT=3000
DB_PORT=5432
WEB_PORT_SET=false
DB_PORT_SET=false

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

# ── Port helpers ────────────────────────────────────────────────────────────
port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -tlnH "sport = :$1" 2>/dev/null | grep -q .
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
  else
    return 1 # can't check — assume available
  fi
}

find_available_port() {
  local start="$1"
  local port="$start"
  local max=$((start + 100))
  [ "$max" -gt 65535 ] && max=65535
  while [ "$port" -le "$max" ]; do
    if ! port_in_use "$port"; then
      echo "$port"
      return
    fi
    port=$((port + 1))
  done
  echo "$start" # fallback: all ports in range busy
}

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
      WEB_PORT_SET=true
      shift 2
      ;;
    --db-port)
      [ $# -lt 2 ] && fail "--db-port requires a value"
      DB_PORT="$2"
      DB_PORT_SET=true
      shift 2
      ;;
    --mode)
      [ $# -lt 2 ] && fail "--mode requires a value: full or frontend"
      MODE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 <project-name> [OPTIONS]"
      echo ""
      echo "Creates a new project from the T3 Stack template."
      echo ""
      echo "Options:"
      echo "  --mode MODE      Project mode: 'full' or 'frontend' (prompted if omitted)"
      echo "                   full: Next.js + tRPC + Prisma + Auth.js"
      echo "                   frontend: Next.js only (no database, auth, or API)"
      echo "  --template REPO  GitHub user/repo to clone via degit (optional)."
      echo "                   If omitted, copies from the local template directory."
      echo "  --web-port PORT  Host port for Next.js dev server (default: 3000)"
      echo "  --db-port PORT   Host port for PostgreSQL (default: 5432, full mode only)"
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
  echo "Usage: $0 <project-name> [--mode MODE] [--template REPO] [--web-port PORT] [--db-port PORT]"
  echo ""
  echo "Creates a new project from the T3 Stack template."
  exit 1
fi

# ── Resolve mode ────────────────────────────────────────────────────────────
if [ -z "$MODE" ]; then
  if [ -t 0 ]; then
    echo ""
    echo "Select project mode:"
    echo ""
    echo "  1) full      — Next.js + tRPC + Prisma + Auth.js"
    echo "  2) frontend  — Next.js only (no database, auth, or API layer)"
    echo ""
    read -r -p "Mode [1/2, default: 1]: " mode_choice
    case "$mode_choice" in
      2|frontend) MODE="frontend" ;;
      1|full|"")  MODE="full" ;;
      *)
        warn "Unrecognized choice '${mode_choice}', defaulting to full mode."
        MODE="full"
        ;;
    esac
    echo ""
  else
    MODE="full"
  fi
fi

if [ "$MODE" != "full" ] && [ "$MODE" != "frontend" ]; then
  fail "Invalid mode '${MODE}'. Use 'full' or 'frontend'."
fi

# ── Resolve ports ───────────────────────────────────────────────────────────
if [ -t 0 ]; then
  if [ "$WEB_PORT_SET" = "false" ]; then
    web_default="$WEB_PORT"
    if port_in_use "$web_default"; then
      web_default=$(find_available_port "$WEB_PORT")
      if [ "$web_default" != "$WEB_PORT" ]; then
        warn "Default web port ${WEB_PORT} is in use, suggesting ${web_default}"
      fi
    fi
    read -r -p "Web port [default: ${web_default}]: " web_port_input
    WEB_PORT="${web_port_input:-$web_default}"
  fi

  if [ "$MODE" = "full" ] && [ "$DB_PORT_SET" = "false" ]; then
    db_default="$DB_PORT"
    if port_in_use "$db_default"; then
      db_default=$(find_available_port "$DB_PORT")
      if [ "$db_default" != "$DB_PORT" ]; then
        warn "Default database port ${DB_PORT} is in use, suggesting ${db_default}"
      fi
    fi
    read -r -p "Database port [default: ${db_default}]: " db_port_input
    DB_PORT="${db_port_input:-$db_default}"
  fi

  echo ""
fi

# ── Validate inputs ──────────────────────────────────────────────────────────
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
  fail "Invalid project name '${PROJECT_NAME}'. Use alphanumeric characters, hyphens, and underscores. Must start with a letter."
fi

DB_NAME="$(printf '%s' "$PROJECT_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/_/g; s/_+/_/g; s/^_+//; s/_+$//')"

if [ -z "$DB_NAME" ]; then
  fail "Unable to derive a database name from '${PROJECT_NAME}'."
fi

if [ -d "$PROJECT_NAME" ]; then
  fail "Directory '${PROJECT_NAME}' already exists."
fi

if [[ ! "$WEB_PORT" =~ ^[0-9]+$ ]] || [ "$WEB_PORT" -lt 1 ] || [ "$WEB_PORT" -gt 65535 ]; then
  fail "Invalid web port '${WEB_PORT}'. Must be a number between 1 and 65535."
fi

if [ "$MODE" = "full" ]; then
  if [[ ! "$DB_PORT" =~ ^[0-9]+$ ]] || [ "$DB_PORT" -lt 1 ] || [ "$DB_PORT" -gt 65535 ]; then
    fail "Invalid database port '${DB_PORT}'. Must be a number between 1 and 65535."
  fi

  if [ "$WEB_PORT" = "$DB_PORT" ]; then
    fail "Web port and database port cannot be the same (both set to ${WEB_PORT})."
  fi
fi

# ── Check port availability ─────────────────────────────────────────────────
check_port() {
  local label="$1" port="$2"
  if port_in_use "$port"; then
    warn "${label} port ${port} is currently in use."
    if [ -t 0 ]; then
      read -r -p "  Continue anyway? [y/N]: " confirm
      case "$confirm" in
        y|Y|yes|YES) ;;
        *) fail "Aborted — choose a different port." ;;
      esac
    else
      fail "${label} port ${port} is already in use."
    fi
  fi
}

check_port "Web" "$WEB_PORT"
if [ "$MODE" = "full" ]; then
  check_port "Database" "$DB_PORT"
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

  // Remove only scripts/create-project.sh from Project Structure
  readme = readme.replace(/├── scripts\/create-project\.sh.*\n/, '');
  readme = readme.replace(/│   ├── create-project\.sh.*\n/, '');

  // Update the default database name to match the generated project
  readme = readme.replaceAll('t3app', '${DB_NAME}');

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

  // Remove only scripts/create-project.sh from Project Structure
  claude = claude.replace(/│   [├└]── create-project\.sh.*\n/, '');

  // Update the default database name to match the generated project
  claude = claude.replaceAll('t3app', '${DB_NAME}');

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

# ── Strip backend (frontend mode) ──────────────────────────────────────────
if [ "$MODE" = "frontend" ]; then
  bash scripts/strip-backend.sh "$PROJECT_NAME" "$WEB_PORT"
fi

# ── Remove template-only files ─────────────────────────────────────────────
rm -f scripts/create-project.sh
rm -f scripts/strip-backend.sh
rm -rf scripts/templates

if [ -d scripts ] && [ -z "$(find scripts -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  rmdir scripts
fi

ok "Removed template-only bootstrap files"

# ── Configure project-specific names and ports (full mode) ──────────────────
if [ "$MODE" = "full" ]; then
  info "Configuring project-specific names..."
  node -e "
    const fs = require('fs');
    const dbName = '${DB_NAME}';

    let envExample = fs.readFileSync('.env.example', 'utf8');
    envExample = envExample.replace(/^POSTGRES_DB=.*$/m, 'POSTGRES_DB=' + dbName);
    envExample = envExample.replace(
      /^DATABASE_URL=.*$/m,
      'DATABASE_URL=\"postgresql://your_db_user:your_strong_password_here@localhost:5432/' + dbName + '\"'
    );
    fs.writeFileSync('.env.example', envExample);

    let dockerCompose = fs.readFileSync('docker-compose.yml', 'utf8');
    dockerCompose = dockerCompose.replaceAll('t3app', dbName);
    fs.writeFileSync('docker-compose.yml', dockerCompose);

    // Also update lat.md docs if present
    const path = require('path');
    const latDir = 'lat.md';
    if (fs.existsSync(latDir)) {
      const walk = (dir) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const full = path.join(dir, entry.name);
          if (entry.isDirectory()) walk(full);
          else if (entry.name.endsWith('.md')) {
            let content = fs.readFileSync(full, 'utf8');
            if (content.includes('t3app')) {
              fs.writeFileSync(full, content.replaceAll('t3app', dbName));
            }
          }
        }
      };
      walk(latDir);
    }
  "
  ok "Database name set to '${DB_NAME}'"

  if [ "$WEB_PORT" != "3000" ] || [ "$DB_PORT" != "5432" ]; then
    info "Configuring custom ports..."

    if [ "$DB_PORT" != "5432" ]; then
      sed -i "s|127.0.0.1:5432:5432|127.0.0.1:${DB_PORT}:5432|" docker-compose.yml
      sed -i "s|localhost:5432|localhost:${DB_PORT}|" .env.example
      ok "Database host port set to ${DB_PORT}"
    fi

    if [ "$WEB_PORT" != "3000" ]; then
      sed -i "s|127.0.0.1:3000:3000|127.0.0.1:${WEB_PORT}:3000|" docker-compose.yml
      ok "Web server host port set to ${WEB_PORT}"
    fi
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

# Generate AUTH_SECRET (full mode only)
if [ "$MODE" = "full" ]; then
  AUTH_SECRET=$(openssl rand -base64 32)
  sed -i "s|^AUTH_SECRET=.*|AUTH_SECRET=\"${AUTH_SECRET}\"|" .env
  ok "Generated AUTH_SECRET"
fi

# ── Validate template placeholders were replaced ─────────────────────────────
if [ "$MODE" = "full" ]; then
  info "Validating generated project names..."
  if grep -RInI \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=.next \
    "t3app" . >/dev/null; then
    fail "Found unreplaced 't3app' references in the generated project."
  fi
  ok "No unreplaced 't3app' references remain"
fi

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
git commit --quiet -m "chore: initialize ${PROJECT_NAME} from template"
ok "Initial commit created"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Project '${PROJECT_NAME}' is ready!  (mode: ${MODE})${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$MODE" = "full" ]; then
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
else
  echo "  Next steps:"
  echo ""
  echo "    cd ${PROJECT_NAME}"
  echo ""
  echo "    # Start the dev server"
  echo "    npm run dev"
  echo ""
  echo "  Or start with Docker:"
  echo ""
  echo "    docker compose up --build"
fi
echo ""
