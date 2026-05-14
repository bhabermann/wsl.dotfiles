#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-habermann-dotfiles-test}"
DOCKER_BIN="${DOCKER_BIN:-docker}"

if ! "$DOCKER_BIN" version >/dev/null 2>&1; then
  if command -v docker.exe >/dev/null 2>&1 && docker.exe version >/dev/null 2>&1; then
    DOCKER_BIN="docker.exe"
  else
    echo "Docker is not available. Enable Docker Desktop WSL integration or set DOCKER_BIN." >&2
    exit 1
  fi
fi

"$DOCKER_BIN" build -f "$ROOT/Dockerfile.test" -t "$IMAGE_NAME" "$ROOT"
"$DOCKER_BIN" run --rm "$IMAGE_NAME"
