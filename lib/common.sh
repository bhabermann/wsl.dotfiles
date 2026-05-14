#!/usr/bin/env bash

DOTFILES_HOME="${DOTFILES_HOME:-$HOME/.dotfiles}"
DOTFILES_CONFIG_DIR="$HOME/.config/dotfiles"
DOTFILES_BACKUP_DIR="$HOME/.dotfiles-backup"
DOTFILES_LOG_DIR="$HOME/.dotfiles-logs"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_STEP=$'\033[1;34m'
  C_SECTION=$'\033[1;36m'
  C_OK=$'\033[1;32m'
  C_WARN=$'\033[1;33m'
  C_ERR=$'\033[1;31m'
  C_LABEL=$'\033[1m'
  C_DIM=$'\033[2m'
else
  C_RESET=""
  C_STEP=""
  C_SECTION=""
  C_OK=""
  C_WARN=""
  C_ERR=""
  C_LABEL=""
  C_DIM=""
fi

section() { printf "\n%s%s%s\n\n" "$C_SECTION" "$*" "$C_RESET"; }
info() { printf "  %s\n" "$*"; }
hint() { printf "  %s%s%s\n" "$C_DIM" "$*" "$C_RESET"; }
item() { printf "  %s-%s %s\n" "$C_DIM" "$C_RESET" "$*"; }
field() { printf "  %s%-16s%s %s\n" "$C_LABEL" "$1:" "$C_RESET" "$2"; }
log() { printf "%s==>%s %s\n" "$C_STEP" "$C_RESET" "$*"; }
ok() { printf "%sOK%s  %s\n" "$C_OK" "$C_RESET" "$*"; }
warn() { printf "%sWARN%s %s\n" "$C_WARN" "$C_RESET" "$*" >&2; }
err() { printf "%sERR%s %s\n" "$C_ERR" "$C_RESET" "$*" >&2; }
die() { err "$*"; exit 1; }
debug() { [[ "${VERBOSE:-0}" == "1" ]] && printf "%sDBG%s %s\n" "$C_DIM" "$C_RESET" "$*" >&2 || true; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_wsl() {
  [[ -n "${WSL_INTEROP:-}" ]] || [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]
}

is_ubuntu_2404() {
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]]
}

confirm() {
  local prompt="$1"
  local default="${2:-Y}"
  local answer

  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    [[ "$default" =~ ^[Yy]$ ]]
    return
  fi

  local label="[y/N]"
  [[ "$default" =~ ^[Yy]$ ]] && label="[Y/n]"
  read -r -p "$prompt $label " answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

confirm_aligned() {
  local name="$1"
  local description="$2"
  local default="${3:-Y}"
  local recommended="${4:-0}"
  local answer label tag

  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    [[ "$default" =~ ^[Yy]$ ]]
    return
  fi

  label="[y/N]"
  [[ "$default" =~ ^[Yy]$ ]] && label="[Y/n]"
  tag=""
  [[ "$recommended" == "1" ]] && tag="${C_OK}(Recommended)${C_RESET} "

  printf "  %s%-5s%s %-12s %s%s\n" "$C_LABEL" "$label" "$C_RESET" "$name" "$tag" "$description" >&2
  read -r -p "        Select ${name} ${label}: " answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

prompt_choice() {
  local prompt="$1"
  local default="$2"
  local answer

  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    printf "%s" "$default"
    return
  fi

  read -r -p "$prompt " answer
  printf "%s" "${answer:-$default}"
}

prompt_value() {
  local prompt="$1"
  local current="${2:-}"
  local value

  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    [[ -n "$current" ]] || die "$prompt is required in non-interactive mode"
    printf "%s" "$current"
    return
  fi

  if [[ -n "$current" ]]; then
    read -r -p "$prompt [$current]: " value
    printf "%s" "${value:-$current}"
  else
    read -r -p "$prompt: " value
    [[ -n "$value" ]] || die "$prompt is required"
    printf "%s" "$value"
  fi
}

backup_path() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local stamp backup
  stamp="$(date +%Y%m%d%H%M%S)"
  backup="$DOTFILES_BACKUP_DIR/$stamp/${path#$HOME/}"
  mkdir -p "$(dirname "$backup")"
  mv "$path" "$backup"
  warn "Backed up $path to $backup"
}

link_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$(readlink -f "$dest" 2>/dev/null || true)" == "$(readlink -f "$src" 2>/dev/null || true)" ]]; then
      return 0
    fi
    backup_path "$dest"
  fi
  ln -s "$src" "$dest"
  ok "Linked $dest"
}

copy_template_if_missing() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" ]]; then
    ok "Keeping existing $dest"
    return 0
  fi
  cp "$src" "$dest"
  ok "Created $dest from template"
}

require_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi
  if sudo -n true 2>/dev/null; then
    return 0
  fi
  if [[ -t 0 ]]; then
    sudo -v
    return 0
  fi
  die "sudo is required"
}
