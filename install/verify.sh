#!/usr/bin/env bash

action_verify() {
  local failed=0
  check "WSL environment" is_wsl || failed=1
  check "Ubuntu 24.04" is_ubuntu_2404 || failed=1
  check_cmd zsh || failed=1
  check_cmd git || failed=1
  if ! check_cmd mise; then
    warn "mise not on PATH; check ~/.local/bin"
  fi
  check_cmd starship || failed=1
  check_cmd zoxide || true
  check_cmd fzf || true
  check_cmd rg || true
  if need_cmd docker; then
    ok "docker"
  else
    warn "Docker missing or Docker Desktop WSL integration disabled"
  fi
  [[ -f "$HOME/.config/git/identity.gitconfig" ]] || { warn "Git identity file missing"; failed=1; }
  [[ -f "$HOME/.ssh/config" ]] || { warn "SSH config missing"; failed=1; }
  return "$failed"
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
