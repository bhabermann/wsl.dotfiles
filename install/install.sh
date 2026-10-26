#!/usr/bin/env bash
action_install() {
  local DOCKER_GROUP_PENDING=0
  section "Single-account Debian WSL"
  if [[ "${DOTFILES_TEST_MODE:-0}" != 1 ]]; then
    is_debian_13 || die "This branch supports Debian 13. Run windows/install.ps1 to create it."
  fi
  resolve_identity
  local resolved_tools
  resolved_tools="$(resolve_tool_selection)"
  mapfile -t SELECTED_TOOLS < <(printf '%s' "$resolved_tools")
  local tool
  for tool in "${WITH_ITEMS[@]}" "${WITHOUT_ITEMS[@]}"; do valid_tool "$tool" || die "Unknown tool: $tool"; done
  if [[ -n "$TOOLS_PRESET" ]]; then
    case "$TOOLS_PRESET" in minimal|recommended|all) ;; *) die "Invalid preset: $TOOLS_PRESET";; esac
  fi
  section "Installation plan"
  field "Identity" "$GIT_NAME <$GIT_EMAIL>"
  field "Core" "zsh Starship zoxide fzf plugins"
  field "Docker" "$DOCKER_STRATEGY"
  field "Optional" "${SELECTED_TOOLS[*]:-(none)}"
  if [[ "$DRY_RUN" == 1 ]]; then ok "Dry run: no changes made"; return; fi
  if [[ "$NON_INTERACTIVE" == 0 ]]; then confirm "Install these components?" Y || die "Cancelled"; fi
  if [[ "${DOTFILES_TEST_MODE:-0}" != 1 ]]; then
    save_git_identity
    require_sudo
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git openssh-client \
      sudo locales less unzip xz-utils gnupg zsh starship zoxide fzf \
      zsh-autosuggestions zsh-syntax-highlighting bash-completion
    sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen en_US.UTF-8
    for tool in "${SELECTED_TOOLS[@]}"; do install_tool "$tool"; done
    "$DOTFILES_ROOT/install/plugins.sh"
    if [[ "$DOCKER_STRATEGY" == wsl-engine ]]; then install_docker; fi
  fi
  mkdir -p "$DOTFILES_CONFIG_DIR" "$HOME/.config/git" "$HOME/.config/mise" "$HOME/src"
  printf '%s\n' "${SELECTED_TOOLS[@]}" | sed '/^$/d' > "$DOTFILES_CONFIG_DIR/selected-tools"
  printf '%s\n' "$DOCKER_STRATEGY" > "$DOTFILES_CONFIG_DIR/docker"
  printf '%s\n' "$DEFAULT_SHELL" > "$DOTFILES_CONFIG_DIR/default-shell"
  export GIT_IDENTITY_WRITE=1 GIT_NAME GIT_EMAIL
  "$DOTFILES_ROOT/install/link.sh"
  if [[ "${DOTFILES_TEST_MODE:-0}" != 1 ]]; then
    if [[ "$DEFAULT_SHELL" != unchanged && "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v "$DEFAULT_SHELL")" ]]; then
      sudo chsh -s "$(command -v "$DEFAULT_SHELL")" "$USER"
    fi
    sudo env DEBIAN_FRONTEND=noninteractive apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    if [[ "$NO_DOCTOR" != 1 ]]; then source "$DOTFILES_ROOT/install/verify.sh"; action_verify embedded; fi
  fi
  ok "Complete. Open a new shell."
}
resolve_identity() {
  local existing_name existing_email
  existing_name="$(git -C "$HOME" config --global --includes user.name 2>/dev/null || true)"
  existing_email="$(git -C "$HOME" config --global --includes user.email 2>/dev/null || true)"
  GIT_NAME="${GIT_NAME:-$existing_name}"
  GIT_EMAIL="${GIT_EMAIL:-$existing_email}"
  if [[ "$NON_INTERACTIVE" == 0 ]]; then
    GIT_NAME="$(prompt_value 'Git name' "$GIT_NAME")"
    GIT_EMAIL="$(prompt_value 'Git email' "$GIT_EMAIL")"
  fi
  [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]] || die "Provide --git-name and --git-email, or configure your existing Git identity."
}
save_git_identity() {
  mkdir -p "$HOME/.config/git"
  local identity="$HOME/.config/git/identity.gitconfig"
  copy_template_if_missing "$DOTFILES_ROOT/templates/git/identity.gitconfig.template" "$identity"
  git -C "$HOME" config --file "$identity" user.name "$GIT_NAME"
  git -C "$HOME" config --file "$identity" user.email "$GIT_EMAIL"
}

install_tool() {
  local tool="$1" package="$1"
  if is_runtime "$tool"; then
    install_mise
    # Dependencies belong to the selected runtime, rather than the minimal base.
    case "$tool" in
      python) sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libssl3t64 zlib1g libbz2-1.0 libreadline8t64 libsqlite3-0 libffi8 liblzma5 ;;
      dotnet) sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libicu76 libssl3t64 libgssapi-krb5-2 zlib1g tzdata ;;
    esac
    local version
    version="$(awk -v key="$tool" '$1 == key {gsub(/"/,"",$3); print $3}' "$DOTFILES_ROOT/mise/default-tools.toml")"
    local request="$tool"
    [[ -z "$version" ]] || request="$tool@$version"
    mise use --global "$request"
    mise where "$request" >/dev/null
    return
  fi
  if [[ "$tool" == mise ]]; then install_mise; return; fi
  case "$tool" in fd) package=fd-find;; bat) package=bat;; esac
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package"
}
install_mise() {
  [[ "${MISE_INSTALLED:-0}" != 1 ]] || return 0
  mkdir -p "$HOME/.config/mise"
  copy_template_if_missing "$DOTFILES_ROOT/mise/config.toml" "$HOME/.config/mise/config.toml"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise.asc >/dev/null
  sudo chmod 644 /etc/apt/keyrings/mise.asc
  printf 'deb [signed-by=/etc/apt/keyrings/mise.asc arch=%s] https://mise.jdx.dev/deb stable main\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
  sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mise
  MISE_INSTALLED=1
}
install_docker() {
  is_wsl || die "Docker installation requires WSL 2"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod 644 /etc/apt/keyrings/docker.asc
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER"
  # usermod changes the account database, not this process's supplementary groups.
  case " $(id -nG) " in
    *" docker "*) ;;
    *) DOCKER_GROUP_PENDING=1 ;;
  esac
  sudo systemctl enable --now docker
  sudo docker info >/dev/null
  sudo install -m 0755 "$DOTFILES_ROOT/scripts/docker-wsl" /usr/local/bin/dotfiles-docker
}
