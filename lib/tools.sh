#!/usr/bin/env bash

ALL_GROUPS=(shell runtime history modern-cli)
INSTALL_ORDER=(corporate-ca runtime shell history modern-cli docker-desktop docker-wsl-engine)
RECOMMENDED_GROUPS=(shell runtime modern-cli)
MINIMAL_GROUPS=(shell)

tool_description() {
  case "$1" in
    shell) printf "Bash and zsh configuration with Starship, zoxide, fzf, and shell plugins." ;;
    modern-cli) printf "Apt-installed search, file listing, readable output, YAML/JSON, GitHub CLI, and tmux tools." ;;
    runtime) printf "mise-managed global Node, .NET, Python, Go, uv, and Java runtimes." ;;
    history) printf "Atuin enhanced searchable shell history." ;;
    docker-desktop) printf "Verify Windows Docker Desktop integration with this WSL distro." ;;
    docker-wsl-engine) printf "Install Docker Engine inside WSL with systemd and Windows wrappers." ;;
    corporate-ca) printf "Refresh configured corporate TLS interception CA certificates into Linux trust." ;;
    *) printf "Custom tool or group." ;;
  esac
}

tool_label() {
  case "$1" in
    shell) printf "Shell" ;;
    modern-cli) printf "Modern CLI" ;;
    runtime) printf "Runtime" ;;
    history) printf "History" ;;
    docker-desktop) printf "Docker Desktop" ;;
    docker-wsl-engine) printf "WSL Docker" ;;
    corporate-ca) printf "Corporate CA" ;;
    *) printf "%s" "$1" ;;
  esac
}

docker_strategy_label() {
  case "$1" in
    docker-wsl-engine|wsl-engine|1) printf "WSL Docker Engine" ;;
    docker-desktop|desktop|2) printf "Docker Desktop" ;;
    none|3|"") printf "None" ;;
    *) printf "%s" "$1" ;;
  esac
}

docker_strategy_from_groups() {
  local group
  for group in "$@"; do
    case "$group" in
      docker-desktop) printf "desktop"; return 0 ;;
      docker-wsl-engine) printf "wsl-engine"; return 0 ;;
    esac
  done
  printf "none"
}

docker_strategy_prompt_default() {
  case "$1" in
    wsl-engine|docker-wsl-engine|"") printf "1" ;;
    desktop|docker-desktop) printf "2" ;;
    none) printf "3" ;;
    *) printf "1" ;;
  esac
}

selection_source_with_overrides() {
  local source="$1"
  if [[ "$#" -gt 1 ]]; then
    shift
    if [[ "$#" -gt 0 ]]; then
      printf "%s + flags" "$source"
      return 0
    fi
  fi
  printf "%s" "$source"
}

is_recommended_group() {
  local item="$1"
  local group
  for group in "${RECOMMENDED_GROUPS[@]}"; do
    [[ "$group" == "$item" ]] && return 0
  done
  return 1
}

contains_item() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

selected_from_preset() {
  case "${TOOLS_PRESET:-recommended}" in
    minimal) printf "%s\n" "${MINIMAL_GROUPS[@]}" ;;
    recommended|preset) printf "%s\n" "${RECOMMENDED_GROUPS[@]}" ;;
    all) printf "%s\n" "${ALL_GROUPS[@]}" ;;
    *) die "Unknown tools preset: $TOOLS_PRESET" ;;
  esac
}

prompt_docker_strategy() {
  local default_choice="${1:-1}"
  local choice default_label
  default_label="$(docker_strategy_label "$default_choice")"
  {
    section "Docker"
    printf "  %s1)%s WSL Docker Engine %s(Recommended)%s - install Docker inside WSL.\n" "$C_LABEL" "$C_RESET" "$C_OK" "$C_RESET"
    printf "  %s2)%s Docker Desktop - verify Windows Docker Desktop WSL integration.\n" "$C_LABEL" "$C_RESET"
    printf "  %s3)%s None - skip Docker setup.\n" "$C_LABEL" "$C_RESET"
    printf "  Current default: %s\n" "$default_label"
  } >&2
  choice="$(prompt_choice "Select Docker strategy [default: $default_choice]:" "$default_choice")"
  case "$choice" in
    1|wsl|wsl-engine|docker-wsl-engine) printf "wsl-engine" ;;
    2|desktop|DockerDesktop|docker-desktop) printf "desktop" ;;
    3|none|no|N|n) printf "none" ;;
    *) die "Unknown Docker strategy: $choice" ;;
  esac
}

resolve_tool_selection() {
  local selected_file final_file ordered_file group parsing_without arg docker_strategy baseline_source
  local saved_groups=()
  local with_items=()
  local without_items=()
  selected_file="$(mktemp)"
  final_file="$(mktemp)"
  ordered_file="$(mktemp)"
  parsing_without=0

  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      parsing_without=1
      continue
    fi
    if [[ "$parsing_without" == "1" ]]; then
      without_items+=("$arg")
    else
      with_items+=("$arg")
    fi
  done

  if [[ "${TOOLS_FLAG:-0}" != "1" && -f "$DOTFILES_CONFIG_DIR/selected-tools" ]]; then
    grep -E '^[A-Za-z0-9_-]+$' "$DOTFILES_CONFIG_DIR/selected-tools" | grep -vx "base" > "$selected_file" || true
    baseline_source="saved state"
  else
    selected_from_preset > "$selected_file"
    if [[ "${TOOLS_FLAG:-0}" == "1" ]]; then
      baseline_source="flag: --tools ${TOOLS_PRESET:-recommended}"
    else
      baseline_source="default preset"
    fi
  fi
  if [[ "${PROFILE:-}" == "work" ]] && ! grep -qx "corporate-ca" "$selected_file"; then
    printf "%s\n" "corporate-ca" >> "$selected_file"
  fi
  mapfile -t saved_groups < "$selected_file"

  docker_strategy="${DOCKER_STRATEGY:-}"
  if [[ -n "$docker_strategy" ]]; then
    DOCKER_SELECTION_SOURCE="flag: --docker $docker_strategy"
  elif [[ "${DOCKER_FLAG:-0}" != "1" && -f "$DOTFILES_CONFIG_DIR/selected-tools" ]]; then
    docker_strategy="$(docker_strategy_from_groups "${saved_groups[@]}")"
    DOCKER_SELECTION_SOURCE="saved state"
  elif [[ "${NON_INTERACTIVE:-0}" == "1" && -z "$docker_strategy" ]]; then
    case "${TOOLS_PRESET:-recommended}" in
      recommended|preset|all) docker_strategy="wsl-engine" ;;
      minimal) docker_strategy="none" ;;
    esac
    DOCKER_SELECTION_SOURCE="default for ${TOOLS_PRESET:-recommended}"
  fi

  for group in "${with_items[@]}"; do
    [[ -n "$group" ]] || continue
    if [[ "$group" == "base" ]]; then
      warn "Ignoring legacy --with base; dependency setup is always run first."
      continue
    fi
    printf "%s\n" "$group" >> "$selected_file"
  done

  sort -u "$selected_file" > "$final_file"
  TOOL_SELECTION_SOURCE="$(selection_source_with_overrides "$baseline_source" "${with_items[@]}" "${without_items[@]}")"

  if [[ "${NON_INTERACTIVE:-0}" == "0" && ( "${RECONFIGURE:-0}" == "1" || ! -f "$DOTFILES_CONFIG_DIR/selected-tools" || "${TOOLS_FLAG:-0}" == "1" ) ]]; then
    section "Tool Selection" >&2
    : > "$final_file"
    for group in "${ALL_GROUPS[@]}"; do
      local default="N"
      if grep -qx "$group" "$selected_file"; then
        default="Y"
      elif [[ "$baseline_source" == "default preset" ]] && is_recommended_group "$group"; then
        default="Y"
      fi
      local badge=""
      is_recommended_group "$group" && badge="recommended"
      [[ "$group" == "history" ]] && badge="optional"
      if confirm_aligned "$(tool_label "$group")" "$(tool_description "$group")" "$default" "$badge"; then
        printf "%s\n" "$group" >> "$final_file"
      fi
    done
    if [[ "${PROFILE:-}" == "work" ]]; then
      section "Work Follow-ups" >&2
      local ca_default="N"
      grep -qx "corporate-ca" "$selected_file" && ca_default="Y"
      if confirm_aligned "$(tool_label corporate-ca)" "$(tool_description corporate-ca)" "$ca_default" ""; then
        printf "%s\n" "corporate-ca" >> "$final_file"
      fi
    fi
    TOOL_SELECTION_SOURCE="prompts"
    [[ "${RECONFIGURE:-0}" == "1" ]] && TOOL_SELECTION_SOURCE="reconfigure prompts"
  fi

  if [[ -z "$docker_strategy" || ( "${NON_INTERACTIVE:-0}" == "0" && ( "${RECONFIGURE:-0}" == "1" || ! -f "$DOTFILES_CONFIG_DIR/selected-tools" || "${DOCKER_FLAG:-0}" == "1" ) && "${DOCKER_FLAG:-0}" != "1" ) ]]; then
    local docker_default
    docker_default="$(docker_strategy_prompt_default "$docker_strategy")"
    docker_strategy="$(prompt_docker_strategy "$docker_default")"
    DOCKER_SELECTION_SOURCE="prompts"
    [[ "${RECONFIGURE:-0}" == "1" ]] && DOCKER_SELECTION_SOURCE="reconfigure prompts"
  fi

  if [[ -n "$docker_strategy" ]]; then
    sed -i '/^docker-desktop$/d;/^docker-wsl-engine$/d' "$final_file"
    case "$docker_strategy" in
      desktop) printf "docker-desktop\n" >> "$final_file" ;;
      wsl-engine) printf "docker-wsl-engine\n" >> "$final_file" ;;
      none) ;;
      *) die "Unknown docker strategy: $docker_strategy" ;;
    esac
  fi

  for group in "${without_items[@]}"; do
    [[ -n "$group" ]] || continue
    if [[ "$group" == "base" ]]; then
      warn "Ignoring legacy --without base; dependency setup is always run first."
      continue
    fi
    sed -i "/^${group}$/d" "$final_file"
  done

  for group in "${with_items[@]}"; do
    [[ -n "$group" && "$group" != "base" ]] && printf "%s\n" "$group" >> "$final_file"
  done

  : > "$ordered_file"
  for group in "${INSTALL_ORDER[@]}"; do
    if grep -qx "$group" "$final_file"; then
      printf "%s\n" "$group" >> "$ordered_file"
    fi
  done

  awk '!seen[$0]++' "$ordered_file"
  rm -f "$selected_file" "$final_file" "$ordered_file"
}
