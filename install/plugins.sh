#!/usr/bin/env bash
set -euo pipefail
# Pin the one plugin not installed by Debian packages.
version=0.35.0
directory="$HOME/.zsh/plugins/zsh-completions"
if [[ ! -d "$directory/.git" ]]; then
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$version" https://github.com/zsh-users/zsh-completions "$directory"
elif [[ "$(git -C "$directory" describe --tags --exact-match 2>/dev/null || true)" != "$version" ]]; then
  git -C "$directory" fetch --depth 1 origin "refs/tags/$version"
  git -C "$directory" checkout --detach FETCH_HEAD
fi
