#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$HOME/.zsh/plugins"
mkdir -p "$PLUGIN_DIR"

clone_plugin() {
  local repo="$1"
  local dest="$2"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only || true
  else
    git clone --depth 1 "$repo" "$dest"
  fi
}

clone_plugin https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/zsh-autosuggestions"
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGIN_DIR/zsh-syntax-highlighting"
clone_plugin https://github.com/zsh-users/zsh-completions "$PLUGIN_DIR/zsh-completions"
