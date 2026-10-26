#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${IMAGE_NAME:-dotfiles-debian-test}"
docker="${DOCKER_BIN:-docker}"
"$docker" info >/dev/null
"$docker" build -f "$root/Dockerfile.test" -t "$image" "$root"
"$docker" run --rm "$image"
