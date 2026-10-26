#!/usr/bin/env bash
action_verify() {
  local mode="${1:-standalone}" failed=0 command
  if is_debian_13; then ok "Debian 13"; else warn "Expected Debian 13"; failed=1; fi
  for command in zsh starship zoxide fzf git; do
    if command -v "$command" >/dev/null; then ok "$command"; else warn "Missing $command"; failed=1; fi
  done
  if managed_source_block_valid "$HOME/.zshrc" zshrc; then ok "Zsh configuration"; else warn "Rerun ./setup install to repair zsh"; failed=1; fi
  if [[ -f "$DOTFILES_CONFIG_DIR/docker" && "$(<"$DOTFILES_CONFIG_DIR/docker")" == wsl-engine ]]; then
    if docker info >/dev/null 2>&1; then ok "Docker Engine"
    elif [[ "$mode" == embedded && "${DOCKER_GROUP_PENDING:-0}" == 1 ]] && sudo -n docker info >/dev/null 2>&1; then
      warn "Docker Engine verified with sudo. Open a new WSL session to activate Docker group membership and use docker without sudo."
    else
      warn "Docker unavailable. Reopen WSL for new docker group membership; check systemctl status docker."
      failed=1
    fi
  fi
  return "$failed"
}
