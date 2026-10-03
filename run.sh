#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_CONTAINER="tourde-database-local"
SERVER_CONTAINER="tourde-server-local"
WEB_CONTAINER="tourde-web-local"
CADDY_CONTAINER="tourde-caddy-local"

cleanup() {
  docker rm -f "$CADDY_CONTAINER" "$WEB_CONTAINER" "$SERVER_CONTAINER" "$MONGO_CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

cleanup

docker build --network host --target debug -t tourde-server:local "$ROOT_DIR/backend"
docker build --network host --target debug -t tourde-web:local "$ROOT_DIR/frontend"
docker build --network host -t tourde-caddy:local "$ROOT_DIR/caddy"

docker run -d \
  --name "$MONGO_CONTAINER" \
  --network host \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD=procMIkradesHESLOzmrde \
  mongo:latest --port 6767 >/dev/null

until docker exec "$MONGO_CONTAINER" \
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

docker run -d \
  --name "$WEB_CONTAINER" \
  --network host \
  -e BACKEND_URL=http://localhost:8000 \
  tourde-web:local >/dev/null

docker run \
  --name "$CADDY_CONTAINER" \
  --network host \
  -e BACKEND_UPSTREAM=http://localhost:8000 \
  -e WEB_UPSTREAM=http://localhost:3000 \
  tourde-caddy:local
