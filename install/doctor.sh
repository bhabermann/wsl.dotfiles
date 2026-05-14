#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_ROOT/lib/common.sh"
source "$DOTFILES_ROOT/install/verify.sh"

action_doctor() {
  local mode="${1:-standalone}"
  [[ "$mode" == "embedded" ]] || section "Doctor"

  action_verify || true

  if [[ -f "$DOTFILES_CONFIG_DIR/profile" ]]; then
    field "Profile" "$(tr -d '[:space:]' < "$DOTFILES_CONFIG_DIR/profile")"
  else
    warn "No profile selected. Run ./setup install."
  fi

  info "Repair hints:"
  item "If mise tools are missing, run: ./setup install --with runtime"
  item "If Docker is missing, enable Docker Desktop WSL integration or run: ./setup install --docker wsl-engine"
  item "If zsh is not default, run: chsh -s \$(command -v zsh)"
}
