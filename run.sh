#!/usr/bin/env bash

set -e

cd ./backend/
cargo run &
BACKEND_PID=$!

cleanup() {
  kill "$BACKEND_PID" 2>/dev/null
}

trap cleanup EXIT INT TERM

cd ../frontend/
bun dev
