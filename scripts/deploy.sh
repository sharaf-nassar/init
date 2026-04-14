#!/usr/bin/env bash
set -euo pipefail

# Deploy the latest code to the production VM.
# Usage: ./scripts/deploy.sh <user@host>
#
# Pulls the latest code, rebuilds containers (code is baked into the image,
# never bind-mounted), runs database migrations, and restarts services.

HOST="${1:?Usage: ./scripts/deploy.sh <user@host>}"

echo "==> Deploying to ${HOST}..."

ssh "${HOST}" 'sudo bash -s' << 'DEPLOY'
set -euo pipefail
cd /opt/app

echo "==> Pulling latest code..."
git pull

echo "==> Building containers..."
docker compose -f docker-compose.prod.yml build

echo "==> Running database migrations..."
docker compose -f docker-compose.prod.yml --profile tools run --rm migrate

echo "==> Restarting services..."
docker compose -f docker-compose.prod.yml up -d

echo "==> Waiting for health check..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "==> Health check passed. Deploy complete."
    exit 0
  fi
  sleep 2
done
echo "==> WARNING: Health check did not pass within 60 seconds."
echo "==> Check logs: docker compose -f docker-compose.prod.yml logs web"
exit 1
DEPLOY
