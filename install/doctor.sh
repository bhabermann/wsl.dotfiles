#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_ROOT/lib/common.sh"
source "$DOTFILES_ROOT/install/verify.sh"

action_doctor() {
  local mode="${1:-standalone}"
  local profile=""
  [[ "$mode" == "embedded" ]] || section "Doctor"

  action_verify || true

  if managed_source_block_valid "$HOME/.bashrc" bashrc; then
    ok "Bash rc managed source block"
  else
    warn "$HOME/.bashrc is missing a valid dotfiles managed block; rerun ./setup install"
  fi
  if managed_source_block_valid "$HOME/.zshrc" zshrc; then
    ok "Zsh rc managed source block"
  else
    warn "$HOME/.zshrc is missing a valid dotfiles managed block; rerun ./setup install"
  fi

  if [[ -f "$DOTFILES_CONFIG_DIR/profile" ]]; then
    profile="$(tr -d '[:space:]' < "$DOTFILES_CONFIG_DIR/profile")"
    field "Profile" "$profile"
  else
    warn "No profile selected. Run ./setup install."
  fi

  tls_diagnostics "$profile"

  info "Available follow-ups:"
  item "Runtime tools are handled when Runtime is selected."
  item "If WSL Docker Engine is selected and docker is unavailable, rerun: ./setup install --docker wsl-engine"
  if [[ "$profile" == "work" ]]; then
    item "If curl, git, mise, npm, package installers, or Docker setup report TLS certificate errors on the corporate network, configure $DOTFILES_CONFIG_DIR/corporate-ca.env and rerun: ./setup install --profile work --with corporate-ca"
  fi
  item "To preview changes before rerunning, use: ./setup install --dry-run"
}

tls_diagnostics() {
  local profile="$1"
  local log_file="${HOME:-/tmp}/.cache/update-corporate-ca.log"
  if [[ -f "$log_file" ]] && grep -qiE "SSL certificate problem|certificate verify failed|TLS verification failed" "$log_file"; then
    warn "Recent corporate CA log contains TLS verification failures: $log_file"
  fi
  if [[ "$profile" == "work" && -f "$DOTFILES_CONFIG_DIR/selected-tools" ]] && ! grep -qx "corporate-ca" "$DOTFILES_CONFIG_DIR/selected-tools"; then
    hint "Work profile detected. Corporate CA refresh is available as an explicit opt-in: ./setup install --profile work --with corporate-ca"
  fi
}
