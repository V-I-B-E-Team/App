#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_CONTAINER="tourde-server-api-local"

cleanup() {
  docker rm -f "$SERVER_CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

cleanup

docker build --network host -t tourde-server:local "$ROOT_DIR/backend"
docker run -d \
  --name "$SERVER_CONTAINER" \
  --network host \
  -e DATABASE_URL=mysql://app:app@localhost:3306/app \
  tourde-server:local >/dev/null

until curl --fail --silent http://localhost:8000/api/v1/health >/dev/null; do
  sleep 1
done

docker run --rm \
  --network host \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$ROOT_DIR/frontend:/app" \
  -w /app \
  oven/bun:1.4.2 \
  sh -c 'bun install --frozen-lockfile && bun run generate-api'
