#!/usr/bin/env bash

ALL_GROUPS=(base shell runtime history modern-cli)
INSTALL_ORDER=(base runtime shell history modern-cli docker-desktop docker-wsl-engine)
RECOMMENDED_GROUPS=(base shell runtime modern-cli)
MINIMAL_GROUPS=(base shell)

tool_description() {
  case "$1" in
    base) printf "Ubuntu essentials for compiling, downloads, certificates, archives, locale, and JSON handling." ;;
    shell) printf "zsh, Starship, zoxide, fzf, and pinned plugins for a fast interactive shell." ;;
    modern-cli) printf "Faster search, file listing, readable output, YAML/JSON tools, and tmux sessions." ;;
    runtime) printf "mise-managed Node, Python, Java, .NET, and Go runtimes." ;;
    history) printf "Atuin enhanced searchable shell history." ;;
    docker-desktop) printf "Verify Windows Docker Desktop integration with this WSL distro." ;;
    docker-wsl-engine) printf "Install Docker Engine inside WSL with systemd and Windows wrappers." ;;
    *) printf "Custom tool or group." ;;
  esac
}

tool_label() {
  case "$1" in
    base) printf "Base" ;;
    shell) printf "Shell" ;;
    modern-cli) printf "Modern CLI" ;;
    runtime) printf "Runtime" ;;
    history) printf "History" ;;
    docker-desktop) printf "Docker Desktop" ;;
    docker-wsl-engine) printf "WSL Docker" ;;
    *) printf "%s" "$1" ;;
  esac
}

docker_strategy_label() {
  case "$1" in
    docker-desktop|desktop) printf "Docker Desktop" ;;
    docker-wsl-engine|wsl-engine) printf "WSL Docker Engine" ;;
    none|"") printf "None" ;;
    *) printf "%s" "$1" ;;
  esac
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
  local choice
  {
    section "Docker"
    printf "  %s1)%s Docker Desktop %s(Recommended)%s - verify Windows Docker Desktop WSL integration.\n" "$C_LABEL" "$C_RESET" "$C_OK" "$C_RESET"
    printf "  %s2)%s WSL Docker Engine - install Docker inside WSL.\n" "$C_LABEL" "$C_RESET"
    printf "  %s3)%s None - skip Docker setup.\n" "$C_LABEL" "$C_RESET"
  } >&2
  choice="$(prompt_choice "Select Docker strategy [default: 1]:" "1")"
  case "$choice" in
    1|desktop|DockerDesktop|docker-desktop) printf "desktop" ;;
    2|wsl|wsl-engine|docker-wsl-engine) printf "wsl-engine" ;;
    3|none|no|N|n) printf "none" ;;
    *) die "Unknown Docker strategy: $choice" ;;
  esac
}

resolve_tool_selection() {
  local selected_file final_file ordered_file group without_base parsing_without arg docker_strategy
  local with_items=()
  local without_items=()
  selected_file="$(mktemp)"
  final_file="$(mktemp)"
  ordered_file="$(mktemp)"
  without_base=0
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

  selected_from_preset > "$selected_file"

  docker_strategy="${DOCKER_STRATEGY:-}"
  if [[ "${NON_INTERACTIVE:-0}" == "1" && -z "$docker_strategy" ]]; then
    case "${TOOLS_PRESET:-recommended}" in
      recommended|preset|all) docker_strategy="desktop" ;;
      minimal) docker_strategy="none" ;;
    esac
  fi

  for group in "${with_items[@]}"; do
    [[ -n "$group" ]] && printf "%s\n" "$group" >> "$selected_file"
  done

  sort -u "$selected_file" > "$final_file"
  if [[ "${NON_INTERACTIVE:-0}" == "0" ]]; then
    section "Tool Selection" >&2
    : > "$final_file"
    for group in "${ALL_GROUPS[@]}"; do
      local default="N"
      is_recommended_group "$group" && default="Y"
      local recommended="0"
      is_recommended_group "$group" && recommended="1"
      if confirm_aligned "$(tool_label "$group")" "$(tool_description "$group")" "$default" "$recommended"; then
        printf "%s\n" "$group" >> "$final_file"
      fi
    done
    docker_strategy="$(prompt_docker_strategy)"
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
    [[ "$group" == "base" ]] && without_base=1
    sed -i "/^${group}$/d" "$final_file"
  done

  for group in "${with_items[@]}"; do
    [[ -n "$group" ]] && printf "%s\n" "$group" >> "$final_file"
  done

  if ! grep -qx "base" "$final_file"; then
    if [[ "$without_base" == "1" ]]; then
      warn "base group disabled by explicit selection"
    else
      printf "base\n" >> "$final_file"
    fi
  fi

  if grep -qx "history" "$final_file" && ! grep -qx "runtime" "$final_file"; then
    warn "history selected; runtime will be installed because Atuin requires mise."
    printf "runtime\n" >> "$final_file"
  fi

  : > "$ordered_file"
  for group in "${INSTALL_ORDER[@]}"; do
    if grep -qx "$group" "$final_file"; then
      printf "%s\n" "$group" >> "$ordered_file"
    fi
  done

  awk '!seen[$0]++' "$ordered_file"
  rm -f "$selected_file" "$final_file" "$ordered_file"
}
