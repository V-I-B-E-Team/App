#! /usr/bin/env bash

cd ./backend/
cargo build

cargo run &
BACKEND_PID=$!

cleanup() {
  kill "$BACKEND_PID" 2>/dev/null
}

trap cleanup EXIT INT TERM

cd ../frontend/
bun i

bun generate-api
