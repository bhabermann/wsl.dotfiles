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
  C_OPTIONAL=$'\033[1;94m'
  C_WARN=$'\033[1;33m'
  C_ERR=$'\033[1;31m'
  C_LABEL=$'\033[1m'
  C_DIM=$'\033[2m'
else
  C_RESET=""
  C_STEP=""
  C_SECTION=""
  C_OK=""
  C_OPTIONAL=""
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

is_ubuntu_2604() {
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]
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
  local badge="${4:-}"
  local answer label tag

  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    [[ "$default" =~ ^[Yy]$ ]]
    return
  fi

  label="[y/N]"
  [[ "$default" =~ ^[Yy]$ ]] && label="[Y/n]"
  tag=""
  case "$badge" in
    recommended|1) tag="${C_OK}(Recommended)${C_RESET} " ;;
    optional) tag="${C_OPTIONAL}(Optional)${C_RESET} " ;;
  esac

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

ensure_managed_source_block() {
  local rc_file="$1"
  local source_file="$2"
  local legacy_target="${3:-}"
  local begin="# >>> dotfiles managed >>>"
  local end="# <<< dotfiles managed <<<"
  local source_line="source \"\$HOME/.config/dotfiles/shell/$source_file\""
  local tmp

  mkdir -p "$(dirname "$rc_file")"
  if [[ -L "$rc_file" ]]; then
    tmp="$(mktemp)"
    if [[ -n "$legacy_target" && "$(readlink -f "$rc_file" 2>/dev/null || true)" == "$(readlink -f "$legacy_target" 2>/dev/null || true)" ]]; then
      : > "$tmp"
    elif [[ -e "$rc_file" ]]; then
      cp -L "$rc_file" "$tmp"
    else
      : > "$tmp"
    fi
    rm "$rc_file"
    mv "$tmp" "$rc_file"
    ok "Migrated $rc_file to a regular user-owned file"
  elif [[ ! -e "$rc_file" ]]; then
    : > "$rc_file"
  fi

  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" -v source_line="$source_line" '
    $0 == begin { if (managed) print buffered; managed=1; buffered=""; next }
    managed && $0 == end { managed=0; buffered=""; next }
    managed {
      if ($0 != source_line && $0 != begin) buffered = buffered $0 ORS
      next
    }
    $0 == end || $0 == source_line { next }
    { print }
    END { if (managed) printf "%s", buffered }
  ' "$rc_file" > "$tmp"

  if [[ -s "$tmp" ]] && [[ "$(tail -c 1 "$tmp" | wc -l)" -eq 0 ]]; then
    printf '\n' >> "$tmp"
  fi
  if [[ -s "$tmp" ]]; then
    printf '\n' >> "$tmp"
  fi
  printf '%s\n%s\n%s\n' "$begin" "$source_line" "$end" >> "$tmp"
  mv "$tmp" "$rc_file"
  ok "Configured $rc_file"
}

managed_source_block_valid() {
  local rc_file="$1"
  local source_file="$2"
  local begin="# >>> dotfiles managed >>>"
  local end="# <<< dotfiles managed <<<"
  local source_line="source \"\$HOME/.config/dotfiles/shell/$source_file\""

  [[ -f "$rc_file" && ! -L "$rc_file" ]] || return 1
  [[ "$(grep -Fxc "$begin" "$rc_file" || true)" == "1" ]] || return 1
  [[ "$(grep -Fxc "$end" "$rc_file" || true)" == "1" ]] || return 1
  [[ "$(grep -Fxc "$source_line" "$rc_file" || true)" == "1" ]] || return 1
  awk -v begin="$begin" -v end="$end" -v source_line="$source_line" '
    $0 == begin {
      if ((getline next_line) <= 0 || next_line != source_line) exit 1
      if ((getline next_line) <= 0 || next_line != end) exit 1
      valid=1
    }
    END { exit(valid ? 0 : 1) }
  ' "$rc_file"
}

copy_or_update_template_with_markers() {
  local src="$1"
  local dest="$2"
  local begin_marker="# BEGIN DOTFILES MANAGED"
  local end_marker="# END DOTFILES MANAGED"
  local tmp before managed after

  mkdir -p "$(dirname "$dest")"

  if [[ ! -e "$dest" ]]; then
    cp "$src" "$dest"
    ok "Created $dest from template"
    return 0
  fi

  if ! grep -qF "$begin_marker" "$dest" || ! grep -qF "$end_marker" "$dest"; then
    warn "$dest exists but lacks managed markers; backing up and recreating"
    backup_path "$dest"
    cp "$src" "$dest"
    ok "Recreated $dest from template"
    return 0
  fi

  tmp="$(mktemp)"
  before="$(mktemp)"
  managed="$(mktemp)"
  after="$(mktemp)"

  # Extract content before BEGIN marker from dest
  awk -v begin="$begin_marker" '
    BEGIN { found = 0 }
    $0 == begin { found = 1; exit }
    { print }
  ' "$dest" > "$before"

  # Extract managed section from source
  awk -v begin="$begin_marker" -v end="$end_marker" '
    BEGIN { in_managed = 0 }
    $0 == begin { in_managed = 1; print; next }
    $0 == end { in_managed = 0; print; next }
    in_managed { print }
  ' "$src" > "$managed"

  # Extract content after END marker (or corrupted variant) from dest
  awk -v end="$end_marker" '
    BEGIN { in_managed = 1; found_end = 0 }
    $0 == end || $0 ~ end { in_managed = 0; found_end = 1; next }
    !in_managed && found_end { print }
  ' "$dest" > "$after"

  # Combine the parts
  cat "$before" > "$tmp"
  cat "$managed" >> "$tmp"
  cat "$after" >> "$tmp"

  rm -f "$before" "$managed" "$after"
  mv "$tmp" "$dest"
  ok "Updated managed section in $dest"
}

validate_managed_markers() {
  local file="$1"
  local begin_marker="# BEGIN DOTFILES MANAGED"
  local end_marker="# END DOTFILES MANAGED"

  [[ -f "$file" ]] || return 1
  [[ "$(grep -Fxc "$begin_marker" "$file" || true)" == "1" ]] || return 1
  [[ "$(grep -Fxc "$end_marker" "$file" || true)" == "1" ]] || return 1

  awk -v begin="$begin_marker" -v end="$end_marker" '
    BEGIN { in_managed = 0; begin_seen = 0; end_seen = 0 }
    $0 == begin { 
      if (in_managed) exit 1
      in_managed = 1
      begin_seen = 1
      next 
    }
    $0 == end { 
      if (!in_managed) exit 1
      in_managed = 0
      end_seen = 1
      next 
    }
    END { exit((begin_seen && end_seen && !in_managed) ? 0 : 1) }
  ' "$file"
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
