#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MYSQL_CONTAINER="tourde-mysql-local"
SERVER_CONTAINER="tourde-server-local"
WEB_CONTAINER="tourde-web-local"
CADDY_CONTAINER="tourde-caddy-local"

cleanup() {
  docker rm -f "$CADDY_CONTAINER" "$WEB_CONTAINER" "$SERVER_CONTAINER" "$MYSQL_CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

cleanup

docker build --network host -t tourde-server:local "$ROOT_DIR/backend"
docker build --network host -t tourde-web:local "$ROOT_DIR/frontend"
docker build --network host -t tourde-caddy:local "$ROOT_DIR/caddy"

docker run -d \
  --name "$MYSQL_CONTAINER" \
  --network host \
  -e MYSQL_DATABASE=app \
  -e MYSQL_USER=app \
  -e MYSQL_PASSWORD=app \
  -e MYSQL_ROOT_PASSWORD=root \
  mysql:8.4 >/dev/null

until docker exec "$MYSQL_CONTAINER" mysqladmin ping -h 127.0.0.1 -uroot -proot --silent >/dev/null 2>&1; do
  sleep 1
done

docker run -d \
  --name "$SERVER_CONTAINER" \
  --network host \
  -e DATABASE_URL=mysql://app:app@localhost:3306/app \
  tourde-server:local >/dev/null

docker run -d \
  --name "$WEB_CONTAINER" \
  --network host \
  -e BACKEND_URL=http://localhost:8000 \
  tourde-web:local >/dev/null

docker run \
  --name "$CADDY_CONTAINER" \
  --network host \
  tourde-caddy:local
