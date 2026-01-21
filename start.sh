#!/usr/bin/env bash
set -euo pipefail

# Railway often expects a top-level start script when the repo contains multiple services.
# This script delegates to the backend folder where the Node.js service lives.

cd "$(dirname "$0")"

if [ -d "backend" ] && [ -f "backend/package.json" ]; then
  echo "→ Building and starting backend from ./backend"
  cd backend
  if command -v npm >/dev/null 2>&1; then
    echo "→ Installing dependencies"
    npm ci --prefer-offline --no-audit --progress=false || npm install
  fi
  echo "→ Starting server"
  exec npm start
else
  echo "Error: backend/package.json not found. Ensure the repository contains a /backend folder with package.json"
  exit 1
fi
