#!/usr/bin/env bash

action_install() {
  local selected_groups group profile_source identity_status docker_choice default_shell_choice selected_tmp

  section "Environment"
  [[ "$DOTFILES_ROOT" == /mnt/* ]] && warn "Recommended: clone dotfiles under the Linux filesystem, not /mnt/c."
  if is_wsl; then
    field "WSL" "detected"
  else
    warn "This project targets Ubuntu 26.04 on WSL2."
  fi
  if is_ubuntu_2604; then
    field "Ubuntu" "26.04"
  else
    warn "This project is designed for Ubuntu 26.04."
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

  resolve_git_identity
  identity_status="$GIT_IDENTITY_STATUS"
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
  field "CA refresh" "Linux trust refresh (always run after dependency setup)"
  info "Tools:"
  for group in "${selected_groups[@]}"; do
    item "$(tool_label "$group"): $(tool_description "$group")"
  done
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
  save_git_identity

  section "Installation"
  install_dependency_setup
  install_corporate_ca
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
  action_complete "$default_shell_choice"
}

resolve_git_identity() {
  local identity_file="$HOME/.config/git/identity.gitconfig"
  local current_name="" current_email="" source=""
  GIT_IDENTITY_WRITE=0

  if [[ -f "$identity_file" ]]; then
    current_name="$(git config --file "$identity_file" --get user.name 2>/dev/null || true)"
    current_email="$(git config --file "$identity_file" --get user.email 2>/dev/null || true)"
    source="$identity_file"
  else
    current_name="$(git config --global --get user.name 2>/dev/null || true)"
    current_email="$(git config --global --get user.email 2>/dev/null || true)"
    [[ -n "$current_name$current_email" ]] && source="existing Git configuration"
  fi
  [[ "$current_name" == "__GIT_NAME__" ]] && current_name=""
  [[ "$current_email" == "__GIT_EMAIL__" ]] && current_email=""

  [[ "${GIT_NAME_FLAG:-0}" == "1" ]] || GIT_NAME="${GIT_NAME:-$current_name}"
  [[ "${GIT_EMAIL_FLAG:-0}" == "1" ]] || GIT_EMAIL="${GIT_EMAIL:-$current_email}"

  if [[ "${GIT_NAME_FLAG:-0}" == "1" || "${GIT_EMAIL_FLAG:-0}" == "1" ]]; then
    GIT_NAME="$(prompt_value "Git name" "${GIT_NAME:-$current_name}")"
    GIT_EMAIL="$(prompt_value "Git email" "${GIT_EMAIL:-$current_email}")"
    GIT_IDENTITY_WRITE=1
  elif [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
    field "Git name" "$GIT_NAME"
    field "Git email" "$GIT_EMAIL"
    [[ -n "$source" ]] && hint "Detected from $source"
    if [[ "${NON_INTERACTIVE:-0}" == "0" ]] && confirm "Change Git identity?" "N"; then
      GIT_NAME="$(prompt_value "Git name" "$GIT_NAME")"
      GIT_EMAIL="$(prompt_value "Git email" "$GIT_EMAIL")"
      GIT_IDENTITY_WRITE=1
    fi
  else
    GIT_NAME="$(prompt_value "Git name" "${GIT_NAME:-$current_name}")"
    GIT_EMAIL="$(prompt_value "Git email" "${GIT_EMAIL:-$current_email}")"
    GIT_IDENTITY_WRITE=1
  fi

  if [[ -f "$identity_file" ]]; then
    GIT_IDENTITY_STATUS="configured as $GIT_NAME <$GIT_EMAIL>"
  else
    GIT_IDENTITY_WRITE=1
    GIT_IDENTITY_STATUS="will create $identity_file as $GIT_NAME <$GIT_EMAIL>"
  fi
  export GIT_NAME GIT_EMAIL GIT_IDENTITY_WRITE GIT_IDENTITY_STATUS
}

save_git_identity() {
  local identity_file="$HOME/.config/git/identity.gitconfig"
  
  if [[ "${GIT_IDENTITY_WRITE:-0}" != "1" ]]; then
    return 0
  fi
  
  if [[ -z "${GIT_NAME:-}" || -z "${GIT_EMAIL:-}" ]]; then
    return 0
  fi
  
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    ok "DRY-RUN: Would create git identity file"
    return 0
  fi
  
  mkdir -p "$HOME/.config/git"
  if [[ ! -f "$identity_file" ]]; then
    copy_template_if_missing "$DOTFILES_ROOT/templates/git/identity.gitconfig.template" "$identity_file"
  fi
  
  git config --file "$identity_file" user.name "$GIT_NAME"
  git config --file "$identity_file" user.email "$GIT_EMAIL"
  ok "Saved git identity to $identity_file"
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
    printf "  %s2)%s Set bash as login shell\n" "$C_LABEL" "$C_RESET" >&2
    printf "  %s3)%s Leave current shell unchanged\n" "$C_LABEL" "$C_RESET" >&2
    case "$shell_default" in
      zsh|1) shell_default="1" ;;
      bash|2) shell_default="2" ;;
      unchanged|none|no|N|n|3) shell_default="3" ;;
      *) shell_default="3" ;;
    esac
    printf "  Current default: %s\n" "$(default_shell_label "$shell_default")" >&2
    choice="$(prompt_choice "Select default shell [default: $shell_default]:" "$shell_default")"
    DEFAULT_SHELL_SOURCE="prompt"
    [[ "${RECONFIGURE:-0}" == "1" ]] && DEFAULT_SHELL_SOURCE="reconfigure prompt"
  fi

  case "$choice" in
    1|zsh) RESOLVED_DEFAULT_SHELL="zsh" ;;
    2|bash) RESOLVED_DEFAULT_SHELL="bash" ;;
    3|unchanged|none|no|N|n) RESOLVED_DEFAULT_SHELL="unchanged" ;;
    *) die "Unknown default shell choice: $choice" ;;
  esac
}

default_shell_label() {
  case "$1" in
    1|zsh) printf "zsh" ;;
    2|bash) printf "bash" ;;
    3|unchanged|none|no|N|n) printf "unchanged" ;;
    *) printf "%s" "$1" ;;
  esac
}

apply_default_shell() {
  local choice="$1"
  local shell_path

  [[ "$choice" == "zsh" || "$choice" == "bash" ]] || return 0

  log "Configuring $choice as login shell"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped login shell change"
    return 0
  fi

  shell_path="$(command -v "$choice" || true)"
  if [[ -z "$shell_path" ]]; then
    warn "$choice is not available; cannot set login shell"
    return 0
  fi

  if [[ "${SHELL:-}" == "$shell_path" ]]; then
    ok "$choice is already the login shell"
    return 0
  fi

  if chsh -s "$shell_path"; then
    ok "Login shell set to $shell_path"
  else
    warn "Could not set login shell automatically. You can retry later with: chsh -s $shell_path"
  fi
}

action_complete() {
  local shell_choice="${1:-unchanged}"
  section "Complete"
  if [[ "$shell_choice" == "zsh" || "$shell_choice" == "bash" ]]; then
    field "Restart shell" "exec $shell_choice"
  else
    field "Restart shell" "start a new shell"
  fi
  field "Preview changes" "./setup install --dry-run"
  field "Reconfigure choices" "./setup install --reconfigure"
  field "Automation example" "./setup install --non-interactive --tools recommended --docker wsl-engine --default-shell zsh"
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
  sudo apt-get install -y build-essential curl wget git openssh-client ca-certificates openssl gnupg jq unzip zip less locales software-properties-common xdg-utils bash-completion util-linux-extra libicu78 libssl3t64 zlib1g libgssapi-krb5-2 tzdata
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
  sudo apt-get install -y zsh fzf direnv starship zoxide zsh-autosuggestions zsh-syntax-highlighting
  "$DOTFILES_ROOT/install/plugins.sh"
}

install_modern_cli() {
  log "Installing modern CLI tools"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped modern CLI installation"
    return 0
  fi
  require_sudo
  sudo apt-get install -y ripgrep fd-find bat tree tmux jq gh eza yq
}

install_runtime() {
  log "Installing mise and runtimes"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped runtime installation"
    "$DOTFILES_ROOT/install/link.sh" --only-mise
    return 0
  fi
  require_sudo
  sudo add-apt-repository -y ppa:jdxcode/mise
  sudo apt-get update -y
  sudo apt-get install -y mise
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  "$DOTFILES_ROOT/install/link.sh" --only-mise
  local mise_cmd
  mise_cmd=""
  [[ -x /usr/bin/mise ]] && mise_cmd=/usr/bin/mise
  [[ -z "$mise_cmd" ]] && mise_cmd="$(command -v mise || true)"
  [[ -z "$mise_cmd" && -x "$HOME/.local/bin/mise" ]] && mise_cmd="$HOME/.local/bin/mise"
  [[ -n "$mise_cmd" ]] || die "mise installation did not provide a usable binary."
  "$mise_cmd" trust "$DOTFILES_ROOT" >/dev/null 2>&1 || true
  configure_runtime_ca_bundle
  ensure_mise_versions_https

  local default_tools_file runtime_pairs pair tool version
  default_tools_file="$DOTFILES_ROOT/mise/default-tools.toml"
  mapfile -t runtime_pairs < <(read_mise_default_tools "$default_tools_file")
  for pair in "${runtime_pairs[@]}"; do
    tool="${pair%%$'\t'*}"
    version="${pair#*$'\t'}"
    "$mise_cmd" use -g "$tool@$version"
  done
  "$mise_cmd" install
  for pair in "${runtime_pairs[@]}"; do
    tool="${pair%%$'\t'*}"
    version="${pair#*$'\t'}"
    if ! "$mise_cmd" where "$tool@$version" >/dev/null 2>&1; then
      die "mise did not install $tool@$version as configured."
    fi
  done
}

configure_runtime_ca_bundle() {
  local ca_bundle="/etc/ssl/certs/ca-certificates.crt"
  [[ -f "$ca_bundle" ]] || die "Missing Linux CA bundle: $ca_bundle"
  export SSL_CERT_FILE="$ca_bundle"
  export CURL_CA_BUNDLE="$ca_bundle"
  export REQUESTS_CA_BUNDLE="$ca_bundle"
}

ensure_mise_versions_https() {
  local urls url err_file failed_url
  urls=(
    "${MISE_VERSIONS_TEST_URL:-https://mise-versions.jdx.dev/data/go.toml}"
    "${MISE_PYTHON_PRECOMPILED_TEST_URL:-https://mise-versions.jdx.dev/tools/python-precompiled-x86_64-unknown-linux-gnu.gz}"
  )
  err_file="$(mktemp)"

  if test_mise_versions_urls "$err_file" "${urls[@]}"; then
    rm -f "$err_file"
    ok "mise versions HTTPS preflight"
    return 0
  fi
  failed_url="$(head -n 1 "$err_file" 2>/dev/null || true)"

  if grep -qiE "certificate|SSL|TLS|unable to get local issuer" "$err_file"; then
    warn "mise versions HTTPS preflight failed TLS verification; refreshing CA trust before retry"
    run_corporate_ca_refresh "mise HTTPS preflight"
    : > "$err_file"
    if test_mise_versions_urls "$err_file" "${urls[@]}"; then
      rm -f "$err_file"
      ok "mise versions HTTPS preflight"
      return 0
    fi
    failed_url="$(head -n 1 "$err_file" 2>/dev/null || true)"
  fi

  warn "mise versions HTTPS preflight failed: $(tail -n 1 "$err_file" 2>/dev/null || true)"
  rm -f "$err_file"
  warn "Retry CA refresh manually with: $DOTFILES_ROOT/scripts/update-corporate-ca --config $DOTFILES_CONFIG_DIR/corporate-ca.env --verbose"
  die "Cannot continue runtime installation until ${failed_url:-mise-versions.jdx.dev} is trusted from this Linux environment."
}

test_mise_versions_urls() {
  local err_file="$1" url tmp_err
  shift
  : > "$err_file"
  for url in "$@"; do
    tmp_err="$(mktemp)"
    if curl -fsSL --connect-timeout 8 --max-time 20 -o /dev/null "$url" 2>"$tmp_err"; then
      rm -f "$tmp_err"
      continue
    fi
    {
      printf "%s\n" "$url"
      cat "$tmp_err"
    } > "$err_file"
    rm -f "$tmp_err"
    return 1
  done
  return 0
}

read_mise_default_tools() {
  local config_file="$1"
  [[ -f "$config_file" ]] || die "Missing runtime config: $config_file"

  local awk_output awk_status
  if awk_output="$(awk '
    BEGIN {
      in_tools = 0
      count = 0
      malformed = 0
    }
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    {
      line = $0
      sub(/[ \t]*#.*/, "", line)
      line = trim(line)
      if (line == "") {
        next
      }
      if (line ~ /^\[[^]]+\]$/) {
        in_tools = (line == "[tools]")
        next
      }
      if (in_tools) {
        eq = index(line, "=")
        if (eq > 1) {
          key = trim(substr(line, 1, eq - 1))
          value = trim(substr(line, eq + 1))
          if (key ~ /^[A-Za-z0-9._-]+$/ && value ~ /^"[^"]+"$/) {
            sub(/^"/, "", value)
            sub(/"$/, "", value)
            print key "\t" value
            count++
            next
          }
        }
        if (line ~ /^[A-Za-z0-9._-]+[ \t]*=[ \t]*"[^"]+"[ \t]*$/) {
          key = line
          sub(/[ \t]*=.*/, "", key)
          value = line
          sub(/^[^=]*=[ \t]*"/, "", value)
          sub(/"[ \t]*$/, "", value)
          print key "\t" value
          count++
          next
        }
        printf "Malformed runtime entry at line %d in %s: %s\n", NR, FILENAME, $0 > "/dev/stderr"
        malformed = 1
        exit 2
      }
    }
    END {
      if (malformed) {
        exit 2
      }
      if (count == 0) {
        exit 3
      }
    }
  ' "$config_file")"; then
    awk_status=0
  else
    awk_status=$?
  fi

  if [[ "$awk_status" -eq 2 ]]; then
    die "Runtime config is malformed: $config_file"
  fi
  if [[ "$awk_status" -eq 3 ]]; then
    die "Runtime config has no [tools] entries: $config_file"
  fi
  if [[ "$awk_status" -ne 0 ]]; then
    die "Failed to parse runtime config: $config_file"
  fi

  printf "%s\n" "$awk_output"
}

install_history() {
  log "Installing Atuin"
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped Atuin installation"
    return 0
  fi
  require_sudo
  sudo apt-get install -y atuin
}

install_corporate_ca() {
  if [[ "${CORPORATE_CA_REFRESH_RAN:-0}" == "1" ]]; then
    ok "Corporate CA refresh already handled after dependency setup"
    return 0
  fi
  CORPORATE_CA_REFRESH_RAN=1
  run_corporate_ca_refresh "after dependency setup"
}

run_corporate_ca_refresh() {
  local context="${1:-}"
  if [[ -n "$context" ]]; then
    log "Preparing corporate CA refresh ($context)"
  else
    log "Preparing corporate CA refresh"
  fi
  copy_or_update_template_with_markers "$DOTFILES_ROOT/templates/dotfiles/corporate-ca.env.template" "$DOTFILES_CONFIG_DIR/corporate-ca.env"
  
  if ! validate_managed_markers "$DOTFILES_CONFIG_DIR/corporate-ca.env"; then
    warn "Corporate CA config has invalid managed markers; repairing"
    copy_or_update_template_with_markers "$DOTFILES_ROOT/templates/dotfiles/corporate-ca.env.template" "$DOTFILES_CONFIG_DIR/corporate-ca.env"
  fi
  
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    ok "DOTFILES_TEST_MODE: skipped corporate CA refresh"
    return 0
  fi
  require_sudo
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
  if ! sudo systemctl enable --now docker; then
    die "Docker could not start through systemd. Ensure /etc/wsl.conf contains [boot] systemd=true, run 'wsl --shutdown' from PowerShell, then rerun setup."
  fi
  sudo docker version >/dev/null || die "Docker Engine was installed but its daemon is not responding."
  install_windows_docker_bridge
  warn "Docker is ready. Start a new shell or run newgrp docker to use it without sudo."
}

install_windows_docker_bridge() {
  local distro script windows_script
  distro="${WSL_DISTRO_NAME:-}"
  [[ -n "$distro" ]] || { warn "WSL_DISTRO_NAME is unavailable; skipped the PowerShell Docker bridge."; return 0; }
  need_cmd powershell.exe || { warn "powershell.exe is unavailable; skipped the PowerShell Docker bridge."; return 0; }
  need_cmd wslpath || { warn "wslpath is unavailable; skipped the PowerShell Docker bridge."; return 0; }
  script="$DOTFILES_ROOT/windows/install-docker-wsl-profile.ps1"
  windows_script="$(wslpath -w "$script")"
  if powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$windows_script" -Distribution "$distro"; then
    ok "PowerShell docker command now targets Docker Engine in $distro"
  else
    warn "Could not configure the PowerShell Docker bridge. Run $script from Windows manually."
  fi
}
