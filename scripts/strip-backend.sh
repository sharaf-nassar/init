#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# strip-backend.sh — Remove backend components for frontend-only mode.
#
# Called by create-project.sh after copying the full template.
# Runs inside the generated project directory.
#
# Usage: strip-backend.sh <project-name> <web-port>
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_NAME="$1"
WEB_PORT="${2:-3000}"

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✔${NC}  $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates/frontend"

# ── Remove backend files ────────────────────────────────────────────────────
info "Removing backend components..."

rm -rf src/server src/trpc prisma prisma.config.ts
rm -f src/middleware.ts src/lib/logger.ts
rm -rf src/app/api
rm -f src/app/_components/create-post-form.tsx
rm -f src/app/_components/post-list.tsx
rm -rf scripts/cloud

ok "Removed backend directories and files"

# ── Copy frontend templates ─────────────────────────────────────────────────
info "Installing frontend templates..."

cp "$TEMPLATES_DIR/page.tsx" src/app/page.tsx
cp "$TEMPLATES_DIR/layout.tsx" src/app/layout.tsx
cp "$TEMPLATES_DIR/env.js" src/env.js
cp "$TEMPLATES_DIR/docker-compose.yml" docker-compose.yml
cp "$TEMPLATES_DIR/.env.example" .env.example
cp "$TEMPLATES_DIR/Dockerfile.dev" Dockerfile.dev

# Replace project name placeholder in templates
sed -i "s/__PROJECT_NAME__/${PROJECT_NAME}/g" src/app/page.tsx src/app/layout.tsx

# Apply custom web port if non-default
if [ "$WEB_PORT" != "3000" ]; then
  sed -i "s|127.0.0.1:3000:3000|127.0.0.1:${WEB_PORT}:3000|" docker-compose.yml
fi

ok "Frontend templates installed"

# ── Strip package.json ──────────────────────────────────────────────────────
info "Stripping backend dependencies..."

node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

  const removeDeps = [
    '@auth/prisma-adapter', '@prisma/adapter-pg', '@tanstack/react-query',
    '@trpc/client', '@trpc/react-query', '@trpc/server',
    'dotenv', 'next-auth', 'pg', 'pino', 'server-only', 'superjson'
  ];
  const removeDevDeps = ['@types/pg', 'pino-pretty', 'prisma'];
  const removeScripts = [
    'db:dev', 'db:migrate', 'db:push', 'db:studio',
    'deploy:cloud', 'postinstall'
  ];

  for (const dep of removeDeps) delete pkg.dependencies[dep];
  for (const dep of removeDevDeps) delete pkg.devDependencies[dep];
  for (const script of removeScripts) delete pkg.scripts[script];

  // Remove 'scripts/' path from lint/format commands (scripts/ dir is deleted)
  for (const key of ['lint', 'lint:fix', 'format']) {
    if (pkg.scripts[key]) {
      pkg.scripts[key] = pkg.scripts[key].replace(' scripts/', '');
    }
  }

  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"

ok "Backend dependencies removed from package.json"

# ── Update README.md ────────────────────────────────────────────────────────
info "Updating README.md for frontend mode..."

node -e "
  const fs = require('fs');
  let readme = fs.readFileSync('README.md', 'utf8');

  // Update description
  readme = readme.replace(
    /Built with the \[T3 Stack\]\(https:\/\/create\.t3\.gg\/\)[^\\n]*/,
    'Built with Next.js — strict TypeScript, Tailwind CSS, and shadcn/ui.'
  );

  // Simplify Tech Stack — remove backend entries
  readme = readme.replace(/- \*\*Prisma 7\*\*[^\\n]*\\n/g, '');
  readme = readme.replace(/- \*\*tRPC 11\*\*[^\\n]*\\n/g, '');
  readme = readme.replace(/- \*\*Auth\.js v5\*\*[^\\n]*\\n/g, '');
  readme = readme.replace(/- \*\*Docker\*\*[^\\n]*PostgreSQL[^\\n]*\\n/, '- **Docker** — Dev container\\n');

  // Remove Cloud Deploy section
  readme = readme.replace(/## Cloud Deploy[\\s\\S]*?(?=\\n## )/, '');

  // Replace Quick Start (Docker)
  readme = readme.replace(
    /## Quick Start \\(Docker\\)[\\s\\S]*?(?=\\n## )/,
    '## Quick Start (Docker)\\n\\n\`\`\`bash\\n# 1. Start the dev container\\ndocker compose up --build\\n\`\`\`\\n\\nThe dev server starts on \`127.0.0.1:${WEB_PORT}\`.\\n'
  );

  // Replace Quick Start (Local)
  readme = readme.replace(
    /## Quick Start \\(Local\\)[\\s\\S]*?(?=\\n## )/,
    '## Quick Start (Local)\\n\\n**Prerequisites:** Node.js 24+, npm\\n\\n\`\`\`bash\\n# 1. Install dependencies\\nnpm install\\n\\n# 2. Start the dev server\\nnpm run dev\\n\`\`\`\\n'
  );

  // Replace Environment Variables section
  readme = readme.replace(
    /## Environment Variables[\\s\\S]*?(?=\\n## )/,
    '## Environment Variables\\n\\n| Variable | Required | Description |\\n|---|---|---|\\n| \`NODE_ENV\` | No | Runtime environment (default: development) |\\n'
  );

  // Replace Available Commands section
  readme = readme.replace(
    /## Available Commands[\\s\\S]*?(?=\\n## )/,
    '## Available Commands\\n\\n\`\`\`bash\\nnpm run dev          # Start dev server (Turbopack)\\nnpm run build        # Production build\\nnpm run typecheck    # TypeScript type checking\\nnpm run lint         # Biome linter (check only)\\nnpm run lint:fix     # Biome linter (check + autofix)\\nnpm run format       # Biome formatter\\n\`\`\`\\n'
  );

  // Replace Project Structure section
  readme = readme.replace(
    /## Project Structure[\\s\\S]*?(?=\\n## )/,
    \`## Project Structure

\\\`\\\`\\\`
├── src/
│   ├── components/ui/            # shadcn/ui components
│   ├── lib/utils.ts              # cn() utility
│   ├── env.js                    # Environment validation
│   ├── styles/globals.css        # Tailwind + theme tokens
│   └── app/
│       ├── page.tsx              # Home page
│       ├── layout.tsx            # Root layout
│       ├── error.tsx             # Error boundary
│       ├── not-found.tsx         # Custom 404
│       ├── loading.tsx           # Loading state
│       └── _components/          # Client components
├── biome.json                    # Linter + formatter config
├── Dockerfile.dev                # Dev container
└── docker-compose.yml            # Dev container config
\\\`\\\`\\\`
\`
  );

  fs.writeFileSync('README.md', readme);
"

ok "README.md updated for frontend mode"

# ── Update CLAUDE.md ────────────────────────────────────────────────────────
info "Updating CLAUDE.md for frontend mode..."

node -e "
  const fs = require('fs');
  let claude = fs.readFileSync('CLAUDE.md', 'utf8');

  // Remove backend commands from Quick Reference
  claude = claude.replace(/npm run deploy:cloud[^\\n]*\\n/g, '');
  claude = claude.replace(/npx prisma studio[^\\n]*\\n/g, '');
  claude = claude.replace(/npx prisma db push[^\\n]*\\n/g, '');
  claude = claude.replace(/npx prisma generate[^\\n]*\\n/g, '');
  claude = claude.replace(/npm run db:dev[^\\n]*\\n/g, '');
  claude = claude.replace(/npm run db:migrate[^\\n]*\\n/g, '');

  // Update canonical examples — remove backend files
  claude = claude.replace(
    'Canonical examples: \`src/server/api/routers/post.ts\`, \`src/server/api/trpc.ts\`, \`src/server/auth/config.ts\`, \`src/app/_components/providers.tsx\`, \`src/env.js\`.',
    'Canonical examples: \`src/app/_components/providers.tsx\`, \`src/env.js\`.'
  );

  fs.writeFileSync('CLAUDE.md', claude);
"

ok "CLAUDE.md updated for frontend mode"
