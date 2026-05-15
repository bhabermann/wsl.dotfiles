#!/usr/bin/env bash

action_install() {
  local selected_groups group profile_source identity_status docker_choice default_shell_choice selected_tmp

  section "Environment"
  [[ "$DOTFILES_ROOT" == /mnt/* ]] && warn "Recommended: clone dotfiles under the Linux filesystem, not /mnt/c."
  if is_wsl; then
    field "WSL" "detected"
  else
    warn "This project targets Ubuntu 24.04 on WSL2."
  fi
  if is_ubuntu_2404; then
    field "Ubuntu" "24.04"
  else
    warn "This project is designed for Ubuntu 24.04."
  fi

  section "Identity"
  profile_source="flag"
  if [[ "${PROFILE_FLAG:-0}" != "1" && -f "$DOTFILES_CONFIG_DIR/profile" ]]; then
    PROFILE="$(tr -d '[:space:]' < "$DOTFILES_CONFIG_DIR/profile")"
    profile_source="saved state"
  elif [[ -z "${PROFILE:-}" ]]; then
    profile_source="prompt"
  fi
  if [[ "${NON_INTERACTIVE:-0}" == "0" && ( -z "$PROFILE" || "${RECONFIGURE:-0}" == "1" ) && "${PROFILE_FLAG:-0}" != "1" ]]; then
    local profile_default="${PROFILE:-personal}"
    PROFILE="$(prompt_choice "Profile [personal/work] [default: $profile_default]:" "$profile_default")"
    if [[ "${RECONFIGURE:-0}" == "1" ]]; then
      profile_source="reconfigure prompt"
    else
      profile_source="prompt"
    fi
  fi
  [[ "$PROFILE" == "personal" || "$PROFILE" == "work" ]] || die "Profile must be personal or work"
  field "Profile" "$PROFILE ($profile_source)"

  if [[ ! -f "$HOME/.config/git/identity.gitconfig" ]]; then
    GIT_NAME="$(prompt_value "Git name" "${GIT_NAME:-}")"
    GIT_EMAIL="$(prompt_value "Git email" "${GIT_EMAIL:-}")"
    identity_status="will create $HOME/.config/git/identity.gitconfig"
  else
    identity_status="configured at $HOME/.config/git/identity.gitconfig"
  fi
  field "Git identity" "$identity_status"

  selected_tmp="$(mktemp)"
  resolve_tool_selection "$@" > "$selected_tmp"
  mapfile -t selected_groups < "$selected_tmp"
  rm -f "$selected_tmp"
  resolve_default_shell
  default_shell_choice="$RESOLVED_DEFAULT_SHELL"

  section "Installation Plan"
  field "Profile" "$PROFILE ($profile_source)"
  field "Tool selection" "${TOOL_SELECTION_SOURCE:-unknown}"
  docker_choice="None"
  if has_selected "docker-desktop" "${selected_groups[@]}"; then
    docker_choice="$(docker_strategy_label docker-desktop)"
  elif has_selected "docker-wsl-engine" "${selected_groups[@]}"; then
    docker_choice="$(docker_strategy_label docker-wsl-engine)"
  fi
  field "Docker" "$docker_choice (${DOCKER_SELECTION_SOURCE:-unknown})"
  field "Default shell" "$default_shell_choice (${DEFAULT_SHELL_SOURCE:-unknown})"
  field "Git identity" "$identity_status"
  field "Dependency setup" "Ubuntu base packages (always installed first)"
  info "Tools:"
  for group in "${selected_groups[@]}"; do
    item "$(tool_label "$group"): $(tool_description "$group")"
  done
  if has_selected "history" "${selected_groups[@]}" && has_selected "runtime" "${selected_groups[@]}"; then
    hint "Dependency note: history uses Atuin through mise, so runtime must be installed."
  fi
  if has_selected "modern-cli" "${selected_groups[@]}" && ! has_selected "runtime" "${selected_groups[@]}"; then
    warn "modern-cli selected without runtime; apt-backed tools will install, mise-backed extras like eza/yq will be skipped."
  fi
  [[ -f "$HOME/.ssh/config" ]] && hint "Preserved: existing SSH config at $HOME/.ssh/config"
  [[ -f "$HOME/.config/git/identity.gitconfig" ]] && hint "Preserved: existing Git identity at $HOME/.config/git/identity.gitconfig"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    section "Complete"
    field "Dry run" "no changes were made"
    field "Run install" "./setup install"
    return 0
  fi

  if [[ "${NON_INTERACTIVE:-0}" == "0" ]]; then
    confirm "Proceed with installation?" "Y" || die "Installation cancelled"
  fi

  mkdir -p "$DOTFILES_CONFIG_DIR" "$HOME/.config/git"
  printf "%s\n" "$PROFILE" > "$DOTFILES_CONFIG_DIR/profile"
  printf "%s\n" "${selected_groups[@]}" > "$DOTFILES_CONFIG_DIR/selected-tools"
  printf "%s\n" "$default_shell_choice" > "$DOTFILES_CONFIG_DIR/default-shell"

  section "Installation"
  install_dependency_setup
  for group in "${selected_groups[@]}"; do
    case "$group" in
      shell) install_shell ;;
      modern-cli) install_modern_cli ;;
      runtime) install_runtime ;;
      history) install_history ;;
      docker-desktop) verify_docker_desktop ;;
      docker-wsl-engine) install_docker_wsl_engine ;;
      corporate-ca) install_corporate_ca ;;
      *) warn "Unknown group skipped: $group" ;;
    esac
  done

  apply_default_shell "$default_shell_choice"

  section "Linking"
  "$DOTFILES_ROOT/install/link.sh"
  if [[ "${NO_DOCTOR:-0}" != "1" ]]; then
    section "Doctor"
    source "$DOTFILES_ROOT/install/doctor.sh"
    action_doctor "embedded"
  fi
  action_complete
}

resolve_default_shell() {
  local choice="${DEFAULT_SHELL:-}"
  local saved_shell=""

  if [[ -n "$choice" ]]; then
    DEFAULT_SHELL_SOURCE="flag: --default-shell $choice"
  elif [[ "${DEFAULT_SHELL_FLAG:-0}" != "1" && -f "$DOTFILES_CONFIG_DIR/default-shell" ]]; then
    saved_shell="$(tr -d '[:space:]' < "$DOTFILES_CONFIG_DIR/default-shell")"
    choice="$saved_shell"
    DEFAULT_SHELL_SOURCE="saved state"
  elif [[ "${DEFAULT_SHELL_FLAG:-0}" != "1" && -f "$DOTFILES_CONFIG_DIR/profile" ]]; then
    choice="unchanged"
    DEFAULT_SHELL_SOURCE="saved state default"
  fi

  if [[ -z "$choice" && "${NON_INTERACTIVE:-0}" == "1" ]]; then
    choice="unchanged"
    DEFAULT_SHELL_SOURCE="non-interactive default"
  fi

  if [[ "${NON_INTERACTIVE:-0}" == "0" && ( -z "$choice" || "${RECONFIGURE:-0}" == "1" ) && "${DEFAULT_SHELL_FLAG:-0}" != "1" ]]; then
    local shell_default="${choice:-zsh}"
    section "Default Shell" >&2
    printf "  %s1)%s Set zsh as login shell %s(Recommended)%s\n" "$C_LABEL" "$C_RESET" "$C_OK" "$C_RESET" >&2
    printf "  %s2)%s Leave current shell unchanged\n" "$C_LABEL" "$C_RESET" >&2
    case "$shell_default" in
      zsh|1) shell_default="1" ;;
      unchanged|none|no|N|n|2) shell_default="2" ;;
      *) shell_default="2" ;;
    esac
    printf "  Current default: %s\n" "$(default_shell_label "$shell_default")" >&2
    choice="$(prompt_choice "Select default shell [default: $shell_default]:" "$shell_default")"
    DEFAULT_SHELL_SOURCE="prompt"
    [[ "${RECONFIGURE:-0}" == "1" ]] && DEFAULT_SHELL_SOURCE="reconfigure prompt"
  fi

  case "$choice" in
    1|zsh) RESOLVED_DEFAULT_SHELL="zsh" ;;
    2|unchanged|none|no|N|n) RESOLVED_DEFAULT_SHELL="unchanged" ;;
    *) die "Unknown default shell choice: $choice" ;;
  esac
}

default_shell_label() {
  case "$1" in
    1|zsh) printf "zsh" ;;
    2|unchanged|none|no|N|n) printf "unchanged" ;;
    *) printf "%s" "$1" ;;
  esac
}

apply_default_shell() {
  local choice="$1"
  local zsh_path

  [[ "$choice" == "zsh" ]] || return 0

  log "Configuring zsh as login shell"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped login shell change"
    return 0
  fi

  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh is not available; cannot set login shell"
    return 0
  fi

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    ok "zsh is already the login shell"
    return 0
  fi

  if chsh -s "$zsh_path"; then
    ok "Login shell set to $zsh_path"
  else
    warn "Could not set login shell automatically. You can retry later with: chsh -s $zsh_path"
  fi
}

action_complete() {
  section "Complete"
  field "Restart shell" "exec zsh"
  field "Preview changes" "./setup install --dry-run"
  field "Reconfigure choices" "./setup install --reconfigure"
  field "Automation example" "./setup install --non-interactive --tools recommended --docker desktop --default-shell zsh"
}

has_selected() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

install_dependency_setup() {
  log "Installing dependency setup: Ubuntu base packages"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped dependency package installation"
    return 0
  fi
  require_sudo
  sudo apt-get update -y
  sudo apt-get install -y build-essential curl wget git ca-certificates gnupg jq unzip zip locales software-properties-common
  sudo locale-gen en_US.UTF-8 >/dev/null || true
  sudo update-locale LANG=en_US.UTF-8 >/dev/null || true
}

install_shell() {
  log "Installing shell tools"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped shell package installation"
    return 0
  fi
  require_sudo
  sudo apt-get install -y zsh fzf direnv
  if ! need_cmd starship; then
    install_starship_user
  fi
  if ! need_cmd zoxide; then
    sudo apt-get install -y zoxide || true
  fi
  "$DOTFILES_ROOT/install/plugins.sh"
}

install_starship_user() {
  local arch target tmp tarball
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) target="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) target="aarch64-unknown-linux-musl" ;;
    *) die "Unsupported Starship architecture: $arch" ;;
  esac

  log "Installing Starship to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  tmp="$(mktemp -d)"
  tarball="$tmp/starship.tar.gz"
  curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-${target}.tar.gz" -o "$tarball"
  tar -xzf "$tarball" -C "$tmp" starship
  install -m 0755 "$tmp/starship" "$HOME/.local/bin/starship"
  rm -rf "$tmp"
  ok "Starship installed at $HOME/.local/bin/starship"
}

install_modern_cli() {
  log "Installing modern CLI tools"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped modern CLI installation"
    return 0
  fi
  require_sudo
  sudo apt-get install -y ripgrep fd-find bat tree tmux jq
  if need_cmd mise; then
    mise use -g eza@latest yq@latest >/dev/null 2>&1 || true
  fi
}

install_runtime() {
  log "Installing mise and runtimes"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped runtime installation"
    "$DOTFILES_ROOT/install/link.sh" --only-mise
    return 0
  fi
  if ! need_cmd mise && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    curl -fsSL https://mise.run | sh
  fi
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  "$DOTFILES_ROOT/install/link.sh" --only-mise
  local mise_cmd
  mise_cmd="$(command -v mise || true)"
  [[ -z "$mise_cmd" && -x "$HOME/.local/bin/mise" ]] && mise_cmd="$HOME/.local/bin/mise"
  if [[ -n "$mise_cmd" ]]; then
    "$mise_cmd" trust "$DOTFILES_ROOT" >/dev/null 2>&1 || true
    "$mise_cmd" install || true
  fi
}

install_history() {
  log "Installing Atuin"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped Atuin installation"
    return 0
  fi
  local mise_cmd
  mise_cmd="$(command -v mise || true)"
  [[ -z "$mise_cmd" && -x "$HOME/.local/bin/mise" ]] && mise_cmd="$HOME/.local/bin/mise"
  if [[ -n "$mise_cmd" ]]; then
    "$mise_cmd" use -g atuin@latest >/dev/null 2>&1 || true
  else
    die "mise is required to install Atuin, but runtime installation did not provide it."
  fi
}

install_corporate_ca() {
  log "Preparing corporate CA refresh"
  copy_template_if_missing "$DOTFILES_ROOT/templates/dotfiles/corporate-ca.env.template" "$DOTFILES_CONFIG_DIR/corporate-ca.env"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped corporate CA refresh"
    return 0
  fi
  require_sudo
  sudo apt-get update -y
  sudo apt-get install -y openssl ca-certificates curl
  if "$DOTFILES_ROOT/scripts/update-corporate-ca" --config "$DOTFILES_CONFIG_DIR/corporate-ca.env"; then
    ok "Corporate CA refresh completed"
  else
    warn "Corporate CA refresh did not complete. Configure $DOTFILES_CONFIG_DIR/corporate-ca.env and retry: $DOTFILES_ROOT/scripts/update-corporate-ca --config $DOTFILES_CONFIG_DIR/corporate-ca.env"
  fi
}

verify_docker_desktop() {
  log "Checking Docker Desktop WSL integration"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped Docker Desktop integration check"
    return 0
  fi
  if need_cmd docker && docker version >/dev/null 2>&1; then
    ok "Docker is available"
  else
    warn "Docker is not available. Enable Docker Desktop WSL integration for this distro."
  fi
}

install_docker_wsl_engine() {
  log "Installing Docker Engine inside WSL"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped Docker Engine installation"
    return 0
  fi
  is_wsl || die "docker-wsl-engine requires WSL"
  require_sudo
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  local codename
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER" || true
  warn "Reopen WSL or run newgrp docker before using docker without sudo."
}
