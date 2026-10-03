#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_CONTAINER="tourde-database-api-local"
SERVER_CONTAINER="tourde-server-api-local"

cleanup() {
  docker rm -f "$SERVER_CONTAINER" "$DATABASE_CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

cleanup

docker build --network host -t tourde-server:local "$ROOT_DIR/backend"

docker run -d \
  --name "$DATABASE_CONTAINER" \
  --network host \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD=procMIkradesHESLOzmrde \
  mongo:latest --port 6767 >/dev/null

until docker exec "$DATABASE_CONTAINER" \
  mongosh --quiet \
  --host 127.0.0.1 \
  --port 6767 \
  --username root \
  --password procMIkradesHESLOzmrde \
  --authenticationDatabase admin \
  --eval 'db.runCommand({ ping: 1 }).ok' 2>/dev/null | grep -q 1; do
  sleep 1
done

docker run -d \
  --name "$SERVER_CONTAINER" \
  --network host \
  tourde-server:local >/dev/null

for attempt in $(seq 1 60); do
  if curl --fail --silent http://localhost:8000/api/v1/health >/dev/null; then
    break
  fi

  if [ "$attempt" -eq 60 ]; then
    echo "API did not become ready. Container logs:" >&2
    docker logs "$SERVER_CONTAINER" >&2
    exit 1
  fi

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
