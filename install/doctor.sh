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

  info "Available follow-ups:"
  item "Runtime tools are handled when Runtime is selected."
  item "If Docker Desktop is selected and docker is unavailable, enable WSL integration in Docker Desktop."
  item "To preview changes before rerunning, use: ./setup install --dry-run"
}
