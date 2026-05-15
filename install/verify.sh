#!/usr/bin/env bash

action_verify() {
  local failed=0
  local selected_file="$DOTFILES_CONFIG_DIR/selected-tools"
  check "WSL environment" is_wsl || failed=1
  check "Ubuntu 24.04" is_ubuntu_2404 || failed=1

  if [[ -f "$selected_file" ]]; then
    ok "selected tools recorded"
  else
    warn "Selected tools file missing; optional tool checks will be informational"
  fi

  check_cmd git || failed=1

  if selected_tool shell; then
    check_cmd zsh || failed=1
    check_cmd starship || failed=1
    check_cmd zoxide || true
    check_cmd fzf || true
  else
    warn "shell tools not checked; shell group was not selected"
  fi

  if selected_tool runtime || selected_tool history; then
    if ! check_cmd mise; then
      warn "mise not on PATH; check ~/.local/bin"
    fi
  else
    warn "mise not checked; runtime group was not selected"
  fi

  if selected_tool modern-cli; then
    check_cmd rg || true
    check_cmd fdfind || true
    check_cmd batcat || true
    check_cmd tree || true
    check_cmd tmux || true
    check_cmd jq || true
    check_cmd gh || true
    check_cmd eza || true
    check_cmd yq || true
  else
    warn "modern CLI tools not checked; modern-cli group was not selected"
  fi

  if selected_tool docker-desktop || selected_tool docker-wsl-engine; then
    if need_cmd docker; then
      ok "docker"
    else
      warn "Docker missing or Docker Desktop WSL integration disabled"
    fi
  else
    warn "Docker not checked; no Docker strategy was selected"
  fi

  if selected_tool corporate-ca; then
    if [[ -x "$DOTFILES_ROOT/scripts/update-corporate-ca" ]]; then
      ok "corporate CA helper"
    else
      warn "corporate CA helper missing"
      failed=1
    fi
    [[ -f "$DOTFILES_CONFIG_DIR/corporate-ca.env" ]] || warn "corporate CA config missing"
  elif [[ "$(current_profile)" == "work" && -x "$DOTFILES_ROOT/scripts/update-corporate-ca" ]]; then
    warn "corporate CA not checked; corporate-ca group was not selected"
  fi

  [[ -f "$HOME/.config/git/identity.gitconfig" ]] || { warn "Git identity file missing"; failed=1; }
  [[ -f "$HOME/.ssh/config" ]] || { warn "SSH config missing"; failed=1; }
  return "$failed"
}

selected_tool() {
  local group="$1"
  local selected_file="$DOTFILES_CONFIG_DIR/selected-tools"
  [[ -f "$selected_file" ]] || return 1
  grep -qx "$group" "$selected_file"
}

current_profile() {
  if [[ -n "${PROFILE:-}" ]]; then
    printf "%s" "$PROFILE"
  elif [[ -f "$DOTFILES_CONFIG_DIR/profile" ]]; then
    tr -d '[:space:]' < "$DOTFILES_CONFIG_DIR/profile"
  fi
}

check() {
  local label="$1"
  shift
  if "$@"; then ok "$label"; else warn "$label"; return 1; fi
}

check_cmd() {
  local cmd="$1"
  if need_cmd "$cmd"; then ok "$cmd"; else warn "$cmd missing"; return 1; fi
}
