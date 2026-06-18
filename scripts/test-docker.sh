#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-habermann-dotfiles-test}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
export IMAGE_NAME DOCKER_BIN

if [[ "$DOCKER_BIN" == "docker" && "${DOTFILES_DOCKER_GROUP_REEXEC:-0}" != "1" ]] \
  && command -v docker >/dev/null 2>&1 && ! docker version >/dev/null 2>&1 \
  && id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker \
  && command -v newgrp >/dev/null 2>&1; then
  export DOTFILES_DOCKER_GROUP_REEXEC=1
  reexec_command="$(printf '%q ' "$0" "$@")"
  printf 'exec %s\n' "$reexec_command" | newgrp docker
  exit $?
fi

if ! "$DOCKER_BIN" version >/dev/null 2>&1; then
  if command -v docker.exe >/dev/null 2>&1 && docker.exe version >/dev/null 2>&1; then
    DOCKER_BIN="docker.exe"
  else
    echo "Docker is not available. Install the recommended WSL Docker Engine with './setup install --docker wsl-engine' or set DOCKER_BIN." >&2
    exit 1
  fi
fi

"$DOCKER_BIN" build -f "$ROOT/Dockerfile.test" -t "$IMAGE_NAME" "$ROOT"
"$DOCKER_BIN" run --rm "$IMAGE_NAME"
