#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "==> bash syntax"
bash -n setup lib/common.sh lib/tools.sh install/*.sh scripts/*.sh scripts/wslview scripts/update-corporate-ca

echo "==> help"
./setup help >/tmp/setup-help.txt
grep -q "Usage: ./setup" /tmp/setup-help.txt
grep -q -- "--reconfigure" /tmp/setup-help.txt

echo "==> package policy"
grep -q "apt-get install -y zsh fzf direnv starship zoxide zsh-autosuggestions zsh-syntax-highlighting" install/install.sh
grep -q "apt-get install -y ripgrep fd-find bat tree tmux jq gh eza yq" install/install.sh
grep -q "apt-get install -y atuin" install/install.sh
grep -q "add-apt-repository -y ppa:jdxcode/mise" install/install.sh
grep -q "apt-get install -y mise" install/install.sh
grep -q "INSTALL_ORDER=(corporate-ca runtime shell history modern-cli docker-desktop docker-wsl-engine)" lib/tools.sh
grep -q "libicu78 libssl3t64 zlib1g libgssapi-krb5-2 tzdata" install/install.sh
grep -q "ca-certificates openssl gnupg" install/install.sh
grep -q "ensure_mise_versions_https" install/install.sh
grep -q "configure_runtime_ca_bundle" install/install.sh
grep -q "python-precompiled_x86_64" install/install.sh || grep -q "python-precompiled-x86_64" install/install.sh
grep -q "SSL_CERT_FILE" install/install.sh
grep -q "bash-completion util-linux-extra" install/install.sh
grep -q "newgrp docker" scripts/test-docker.sh
! grep -q "sg docker" scripts/test-docker.sh
grep -q '"\$mise_cmd" where "\$tool@\$version"' install/install.sh
! grep -q "https://mise.run" install/install.sh
! grep -q "starship/releases" install/install.sh
! grep -q "zsh-autosuggestions" install/plugins.sh
! grep -q "zsh-syntax-highlighting" install/plugins.sh
grep -q "zsh-completions" install/plugins.sh
! grep -Eq 'mise use -g .*eza' install/install.sh
! grep -Eq 'mise use -g .*yq' install/install.sh
grep -q 'default_tools_file="\$DOTFILES_ROOT/mise/default-tools.toml"' install/install.sh
grep -q '"\$mise_cmd" use -g "\$tool@\$version"' install/install.sh
grep -q 'node = "24.17.0"' mise/default-tools.toml
grep -q 'python = "3.13.14"' mise/default-tools.toml
grep -q 'java = "21"' mise/default-tools.toml
grep -q 'dotnet = "10.0.301"' mise/default-tools.toml
grep -q 'go = "1.26.3"' mise/default-tools.toml
grep -q 'uv = "0.11.21"' mise/default-tools.toml
! grep -Eq '^(zoxide|eza|bat|ripgrep|fd|jq|yq) =' mise/default-tools.toml
! grep -Eq '^(atuin|eza|yq) =' mise/config.toml

echo "==> optional badge"
printf '\n' | NO_COLOR=1 bash -lc 'source /workspace/lib/common.sh; NON_INTERACTIVE=0; confirm_aligned History "Atuin enhanced searchable shell history." N optional' >/tmp/optional-badge.txt 2>&1 || true
grep -q "(Optional).*Atuin" /tmp/optional-badge.txt

echo "==> Windows browser bridge"
browser_tmp="$(mktemp -d)"
cat > "$browser_tmp/explorer-mock" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$@" > /tmp/wslview-target.txt
EOF
chmod +x "$browser_tmp/explorer-mock"
WSLVIEW_EXPLORER="$browser_tmp/explorer-mock" ./scripts/wslview 'https://example.com/path?a=1&b=2'
grep -Fxq 'https://example.com/path?a=1&b=2' /tmp/wslview-target.txt
if WSLVIEW_EXPLORER="$browser_tmp/explorer-mock" ./scripts/wslview relative-missing-path >/dev/null 2>&1; then
  exit 1
fi

echo "==> runtime config parser"
bash -lc '
  set -euo pipefail
  DOTFILES_ROOT=/workspace
  source /workspace/lib/common.sh
  source /workspace/install/install.sh
  valid="$(mktemp)"
  cat > "$valid" <<'\''EOF'\''
[tools]
node = "lts"
python = "latest"
EOF
  actual="$(read_mise_default_tools "$valid")"
  expected="$(printf "node\tlts\npython\tlatest\n")"
  test "$actual" = "$expected"
'

if bash -lc '
  set -euo pipefail
  DOTFILES_ROOT=/workspace
  source /workspace/lib/common.sh
  source /workspace/install/install.sh
  malformed="$(mktemp)"
  cat > "$malformed" <<'\''EOF'\''
[tools]
node = lts
EOF
  read_mise_default_tools "$malformed" >/tmp/mise-parse-malformed.txt 2>&1
'; then
  exit 1
fi

if bash -lc '
  set -euo pipefail
  DOTFILES_ROOT=/workspace
  source /workspace/lib/common.sh
  source /workspace/install/install.sh
  read_mise_default_tools /tmp/mise-does-not-exist.toml >/tmp/mise-parse-missing.txt 2>&1
'; then
  exit 1
fi

echo "==> tool selection parser"
actual="$(mktemp)"
expected="$(mktemp)"
bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=desktop resolve_tool_selection history -- modern-cli' > "$actual"
printf "%s\n" runtime shell history docker-desktop > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=all DOCKER_STRATEGY=none resolve_tool_selection -- history' > "$actual"
printf "%s\n" runtime shell modern-cli > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=minimal DOCKER_STRATEGY=none resolve_tool_selection history --' > "$actual"
printf "%s\n" shell history > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=wsl-engine resolve_tool_selection --' > "$actual"
printf "%s\n" runtime shell modern-cli docker-wsl-engine > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=recommended resolve_tool_selection --' > "$actual"
printf "%s\n" runtime shell modern-cli docker-wsl-engine > "$expected"
diff -u "$expected" "$actual"

saved_home="$(mktemp -d)"
mkdir -p "$saved_home/.config/dotfiles"
printf "%s\n" base shell history docker-wsl-engine > "$saved_home/.config/dotfiles/selected-tools"
HOME="$saved_home" bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 resolve_tool_selection --' > "$actual"
printf "%s\n" shell history docker-wsl-engine > "$expected"
diff -u "$expected" "$actual"

HOME="$saved_home" bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 resolve_tool_selection modern-cli -- history' > "$actual"
printf "%s\n" shell modern-cli docker-wsl-engine > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=minimal DOCKER_STRATEGY=none resolve_tool_selection base --' > "$actual" 2>/tmp/with-base-warning.txt
printf "%s\n" shell > "$expected"
diff -u "$expected" "$actual"
grep -q "Ignoring legacy --with base" /tmp/with-base-warning.txt

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=minimal DOCKER_STRATEGY=none resolve_tool_selection -- base' > "$actual" 2>/tmp/without-base-warning.txt
printf "%s\n" shell > "$expected"
diff -u "$expected" "$actual"
grep -q "Ignoring legacy --without base" /tmp/without-base-warning.txt

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; PROFILE=personal NON_INTERACTIVE=1 TOOLS_PRESET=all DOCKER_STRATEGY=none resolve_tool_selection --' > "$actual"
! grep -qx "corporate-ca" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; PROFILE=work NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=none resolve_tool_selection --' > "$actual"
grep -qx "corporate-ca" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; PROFILE=work NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=none resolve_tool_selection corporate-ca --' > "$actual"
grep -qx "corporate-ca" "$actual"

printf "\n\n\n\ny\n3\n" | bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; PROFILE=work NON_INTERACTIVE=0 TOOLS_PRESET=minimal resolve_tool_selection --' > "$actual"
grep -qx "corporate-ca" "$actual"
! grep -qx "docker-desktop" "$actual"
! grep -qx "docker-wsl-engine" "$actual"

echo "==> corporate CA helper smoke"
./scripts/update-corporate-ca --help >/tmp/update-corporate-ca-help.txt
grep -q "update-corporate-ca" /tmp/update-corporate-ca-help.txt

ca_config="$(mktemp)"
cat > "$ca_config" <<'EOF'
HOSTS=("127.0.0.1")
TEST_URLS=()
EOF
./scripts/update-corporate-ca --config "$ca_config" --print-config >/tmp/update-corporate-ca-config.txt
grep -q "127.0.0.1" /tmp/update-corporate-ca-config.txt
grep -q "mise-versions.jdx.dev" /tmp/update-corporate-ca-config.txt
grep -q "HOST_CHAIN_ISSUER_IMPORT" /tmp/update-corporate-ca-config.txt
./scripts/update-corporate-ca --config "$ca_config" --dry-run >/tmp/update-corporate-ca-dry-run.txt 2>&1
grep -q "Dry-run completed" /tmp/update-corporate-ca-dry-run.txt
HOME=/tmp/dotfiles-missing-ca-home ./scripts/update-corporate-ca --print-config >/tmp/update-corporate-ca-missing.txt 2>&1
grep -q "mise-versions.jdx.dev" /tmp/update-corporate-ca-missing.txt

echo "==> non-interactive test-mode install"
export HOME=/tmp/dotfiles-home
export DOTFILES_TEST_MODE=1
rm -rf "$HOME"
mkdir -p "$HOME"
printf 'export USER_BASHRC_SURVIVED=1\n' > "$HOME/.bashrc"
printf 'export USER_ZSHRC_SURVIVED=1\n' > "$HOME/.zshrc"

./setup install \
  --non-interactive \
  --profile personal \
  --git-name "Test User" \
  --git-email test@example.com \
  --tools minimal \
  --docker none \
  --default-shell zsh 2>&1 | tee /tmp/setup-install-first.txt

grep -q "^Environment$" /tmp/setup-install-first.txt
grep -q "^Identity$" /tmp/setup-install-first.txt
grep -q "^Installation Plan$" /tmp/setup-install-first.txt
grep -q "^Installation$" /tmp/setup-install-first.txt
grep -q "^Linking$" /tmp/setup-install-first.txt
grep -q "^Doctor$" /tmp/setup-install-first.txt
grep -q "^Complete$" /tmp/setup-install-first.txt
! grep -q "Dotfiles doctor" /tmp/setup-install-first.txt
grep -q "Git identity:.*will create" /tmp/setup-install-first.txt
grep -q "Dependency setup:.*Ubuntu base packages (always installed first)" /tmp/setup-install-first.txt
grep -q "CA refresh:.*Linux trust refresh" /tmp/setup-install-first.txt
grep -q "Installing dependency setup: Ubuntu base packages" /tmp/setup-install-first.txt
grep -q "DOTFILES_TEST_MODE: skipped dependency package installation" /tmp/setup-install-first.txt
grep -q "Preparing corporate CA refresh" /tmp/setup-install-first.txt
dependency_line="$(grep -n "Installing dependency setup: Ubuntu base packages" /tmp/setup-install-first.txt | cut -d: -f1 | head -n1)"
ca_line="$(grep -n "Preparing corporate CA refresh" /tmp/setup-install-first.txt | cut -d: -f1 | head -n1)"
shell_line="$(grep -n "Installing shell tools" /tmp/setup-install-first.txt | cut -d: -f1 | head -n1)"
test "$dependency_line" -lt "$shell_line"
test "$dependency_line" -lt "$ca_line"
test "$ca_line" -lt "$shell_line"
grep -q "Default shell:.*zsh" /tmp/setup-install-first.txt
grep -q "DOTFILES_TEST_MODE: skipped login shell change" /tmp/setup-install-first.txt

test "$(cat "$HOME/.config/dotfiles/profile")" = "personal"
test "$(cat "$HOME/.config/dotfiles/root")" = "/workspace"
test -f "$HOME/.bashrc"
test ! -L "$HOME/.bashrc"
test -f "$HOME/.zshrc"
test ! -L "$HOME/.zshrc"
test -L "$HOME/.config/dotfiles/shell/shared.sh"
test -L "$HOME/.config/dotfiles/shell/bashrc"
test -L "$HOME/.config/dotfiles/shell/zshrc"
test "$(grep -Fxc '# >>> dotfiles managed >>>' "$HOME/.bashrc")" = 1
test "$(grep -Fxc '# >>> dotfiles managed >>>' "$HOME/.zshrc")" = 1
grep -Fqx 'export USER_BASHRC_SURVIVED=1' "$HOME/.bashrc"
grep -Fqx 'export USER_ZSHRC_SURVIVED=1' "$HOME/.zshrc"
test -L "$HOME/.gitconfig"
test -L "$HOME/.config/mise/config.toml"
test -L "$HOME/.config/mise/default-tools.toml"
test -L "$HOME/.config/starship.toml"
test -L "$HOME/.local/bin/wslview"
test -f "$HOME/.config/git/identity.gitconfig"
test -f "$HOME/.ssh/config"
test -f "$HOME/.config/dotfiles/selected-tools"
test -f "$HOME/.config/dotfiles/corporate-ca.env"
test "$(cat "$HOME/.config/dotfiles/default-shell")" = "zsh"
! grep -qx "base" "$HOME/.config/dotfiles/selected-tools"
! grep -qx "corporate-ca" "$HOME/.config/dotfiles/selected-tools"
grep -q "Test User" "$HOME/.config/git/identity.gitconfig"
grep -q "test@example.com" "$HOME/.config/git/identity.gitconfig"
zsh -ic 'test "$DOTFILES" = "/workspace"'
zsh -ic 'test "$USER_ZSHRC_SURVIVED" = 1'
zsh -ic 'alias ll' | grep -q 'ls -la'
zsh -ic 'whence -w path_prepend' | grep -q 'function'
! zsh -ic 'true' 2>&1 | grep -q 'no matches found'
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'test "$DOTFILES" = "/workspace"'
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'test "$USER_BASHRC_SURVIVED" = 1'
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'alias ll' | grep -q 'ls -la'
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'declare -F path_prepend' >/dev/null

echo "==> idempotency"
before_identity="$(sha256sum "$HOME/.config/git/identity.gitconfig")"
before_ssh="$(sha256sum "$HOME/.ssh/config")"

./setup install \
  --non-interactive \
  --profile personal \
  --git-name "Changed User" \
  --git-email changed@example.com \
  --tools minimal \
  --docker none \
  --default-shell unchanged 2>&1 | tee /tmp/setup-install-second.txt

grep -q "Profile:.*personal" /tmp/setup-install-second.txt
grep -q "Git identity:.*configured as Changed User <changed@example.com>" /tmp/setup-install-second.txt
grep -q "Default shell:.*unchanged" /tmp/setup-install-second.txt

./setup install \
  --non-interactive \
  --no-doctor 2>&1 | tee /tmp/setup-install-detected.txt

grep -q "Profile:.*personal (saved state)" /tmp/setup-install-detected.txt
grep -q "Git identity:.*configured as Changed User <changed@example.com>" /tmp/setup-install-detected.txt
grep -q "Tool selection:.*saved state" /tmp/setup-install-detected.txt
grep -q "Docker:.*None (saved state)" /tmp/setup-install-detected.txt
grep -q "Default shell:.*unchanged" /tmp/setup-install-detected.txt

after_identity="$(sha256sum "$HOME/.config/git/identity.gitconfig")"
after_ssh="$(sha256sum "$HOME/.ssh/config")"
test "$before_identity" != "$after_identity"
test "$before_ssh" = "$after_ssh"
grep -q "Changed User" "$HOME/.config/git/identity.gitconfig"
grep -q "changed@example.com" "$HOME/.config/git/identity.gitconfig"
test "$(grep -Fxc '# >>> dotfiles managed >>>' "$HOME/.bashrc")" = 1
test "$(grep -Fxc '# >>> dotfiles managed >>>' "$HOME/.zshrc")" = 1
grep -Fqx 'export USER_BASHRC_SURVIVED=1' "$HOME/.bashrc"
grep -Fqx 'export USER_ZSHRC_SURVIVED=1' "$HOME/.zshrc"

echo "==> rc block repair"
printf '%s\n' '# >>> dotfiles managed >>>' 'source "$HOME/.config/dotfiles/shell/bashrc"' '# <<< dotfiles managed <<<' '# >>> dotfiles managed >>>' 'source "$HOME/.config/dotfiles/shell/bashrc"' '# <<< dotfiles managed <<<' 'export BASH_REPAIR_SURVIVED=1' > "$HOME/.bashrc"
printf '%s\n' 'export ZSH_REPAIR_SURVIVED=1' '# >>> dotfiles managed >>>' 'source "$HOME/.config/dotfiles/shell/zshrc"' > "$HOME/.zshrc"
./setup doctor >/tmp/setup-doctor-malformed.txt 2>&1
grep -q '.bashrc is missing a valid dotfiles managed block' /tmp/setup-doctor-malformed.txt
grep -q '.zshrc is missing a valid dotfiles managed block' /tmp/setup-doctor-malformed.txt
./setup install --non-interactive --no-doctor >/tmp/setup-repair.txt 2>&1
test "$(grep -Fxc '# >>> dotfiles managed >>>' "$HOME/.bashrc")" = 1
test "$(grep -Fxc '# >>> dotfiles managed >>>' "$HOME/.zshrc")" = 1
grep -Fqx 'export BASH_REPAIR_SURVIVED=1' "$HOME/.bashrc"
grep -Fqx 'export ZSH_REPAIR_SURVIVED=1' "$HOME/.zshrc"

echo "==> reconfigure keeps saved values"
printf "\nn\n\n\n\n\n\n\ny\n" | ./setup install --reconfigure --no-doctor 2>&1 | tee /tmp/setup-reconfigure-keep.txt
grep -q "Profile:.*personal (reconfigure prompt)" /tmp/setup-reconfigure-keep.txt
grep -q "Tool selection:.*reconfigure prompts" /tmp/setup-reconfigure-keep.txt
grep -q "Docker:.*None (reconfigure prompts)" /tmp/setup-reconfigure-keep.txt
grep -q "Default shell:.*unchanged (reconfigure prompt)" /tmp/setup-reconfigure-keep.txt
test "$(cat "$HOME/.config/dotfiles/default-shell")" = "unchanged"
printf "%s\n" shell > "$expected"
diff -u "$expected" "$HOME/.config/dotfiles/selected-tools"

echo "==> reconfigure changes saved values"
printf "\nn\n\n\n\n\n1\n1\ny\n" | ./setup install --reconfigure --no-doctor 2>&1 | tee /tmp/setup-reconfigure-change.txt
grep -q "Docker:.*WSL Docker Engine (reconfigure prompts)" /tmp/setup-reconfigure-change.txt
grep -q "Default shell:.*zsh (reconfigure prompt)" /tmp/setup-reconfigure-change.txt
grep -qx "docker-wsl-engine" "$HOME/.config/dotfiles/selected-tools"
test "$(cat "$HOME/.config/dotfiles/default-shell")" = "zsh"

echo "==> dry-run"
rm -rf /tmp/dotfiles-dry-home
mkdir -p /tmp/dotfiles-dry-home
HOME=/tmp/dotfiles-dry-home ./setup install \
  --dry-run \
  --non-interactive \
  --profile personal \
  --git-name "Dry Run" \
  --git-email dry@example.com \
  --tools minimal \
  --docker none 2>&1 | tee /tmp/setup-dry-run.txt

grep -q "^Installation Plan$" /tmp/setup-dry-run.txt
grep -q "^Complete$" /tmp/setup-dry-run.txt
grep -q "Dependency setup:.*Ubuntu base packages (always installed first)" /tmp/setup-dry-run.txt
grep -q "Dry run:.*no changes were made" /tmp/setup-dry-run.txt
! grep -q "^Installation$" /tmp/setup-dry-run.txt
! grep -q "Installing dependency setup" /tmp/setup-dry-run.txt
! grep -q "^Linking$" /tmp/setup-dry-run.txt
test ! -e /tmp/dotfiles-dry-home/.zshrc
test ! -e /tmp/dotfiles-dry-home/.gitconfig
test ! -e /tmp/dotfiles-dry-home/.config/dotfiles/profile
test ! -e /tmp/dotfiles-dry-home/.config/dotfiles/root
test ! -e /tmp/dotfiles-dry-home/.config/dotfiles/selected-tools
test ! -e /tmp/dotfiles-dry-home/.config/dotfiles/default-shell
test ! -e /tmp/dotfiles-dry-home/.config/git/identity.gitconfig
test ! -e /tmp/dotfiles-dry-home/.local/bin/wslview

echo "==> existing install without default-shell"
rm -rf /tmp/dotfiles-old-home
mkdir -p /tmp/dotfiles-old-home/.config/dotfiles /tmp/dotfiles-old-home/.config/git /tmp/dotfiles-old-home/.ssh
printf "personal\n" > /tmp/dotfiles-old-home/.config/dotfiles/profile
printf "%s\n" base shell > /tmp/dotfiles-old-home/.config/dotfiles/selected-tools
printf "[user]\n\tname = Existing\n\temail = existing@example.com\n" > /tmp/dotfiles-old-home/.config/git/identity.gitconfig
printf "Host *\n" > /tmp/dotfiles-old-home/.ssh/config
HOME=/tmp/dotfiles-old-home ./setup install \
  --non-interactive \
  --no-doctor 2>&1 | tee /tmp/setup-old-home.txt
grep -q "Default shell:.*unchanged (saved state default)" /tmp/setup-old-home.txt
test "$(cat /tmp/dotfiles-old-home/.config/dotfiles/default-shell)" = "unchanged"
printf "%s\n" shell > "$expected"
diff -u "$expected" /tmp/dotfiles-old-home/.config/dotfiles/selected-tools

echo "==> legacy zshrc symlink migration"
rm -rf /tmp/dotfiles-legacy-zsh-home
mkdir -p /tmp/dotfiles-legacy-zsh-home
legacy_zshrc_hash="$(sha256sum /workspace/zsh/zshrc)"
ln -s /workspace/zsh/zshrc /tmp/dotfiles-legacy-zsh-home/.zshrc
HOME=/tmp/dotfiles-legacy-zsh-home DOTFILES_ROOT=/workspace /workspace/install/link.sh >/tmp/link-legacy-zsh.txt
test -f /tmp/dotfiles-legacy-zsh-home/.zshrc
test ! -L /tmp/dotfiles-legacy-zsh-home/.zshrc
grep -Fqx 'source "$HOME/.config/dotfiles/shell/zshrc"' /tmp/dotfiles-legacy-zsh-home/.zshrc
test "$legacy_zshrc_hash" = "$(sha256sum /workspace/zsh/zshrc)"

echo "==> bash login-shell selection"
rm -rf /tmp/dotfiles-bash-shell-home
mkdir -p /tmp/dotfiles-bash-shell-home
HOME=/tmp/dotfiles-bash-shell-home ./setup install \
  --non-interactive --no-doctor --profile personal \
  --git-name "Bash User" --git-email bash@example.com \
  --tools minimal --docker none --default-shell bash >/tmp/setup-bash-shell.txt 2>&1
grep -q 'Default shell:.*bash' /tmp/setup-bash-shell.txt
grep -q 'Configuring bash as login shell' /tmp/setup-bash-shell.txt
test "$(cat /tmp/dotfiles-bash-shell-home/.config/dotfiles/default-shell)" = bash

echo "==> corporate CA selected install"
rm -rf /tmp/dotfiles-work-ca-home
mkdir -p /tmp/dotfiles-work-ca-home
HOME=/tmp/dotfiles-work-ca-home ./setup install \
  --non-interactive \
  --profile work \
  --git-name "Work CA" \
  --git-email workca@example.com \
  --tools minimal \
  --with runtime \
  --docker none \
  --default-shell unchanged 2>&1 | tee /tmp/setup-work-ca.txt

grep -q "Corporate CA" /tmp/setup-work-ca.txt
ca_line="$(grep -n "Preparing corporate CA refresh" /tmp/setup-work-ca.txt | cut -d: -f1 | head -n1)"
runtime_line="$(grep -n "Installing mise and runtimes" /tmp/setup-work-ca.txt | cut -d: -f1 | head -n1)"
test "$ca_line" -lt "$runtime_line"
grep -q "DOTFILES_TEST_MODE: skipped corporate CA refresh" /tmp/setup-work-ca.txt
test -f /tmp/dotfiles-work-ca-home/.config/dotfiles/corporate-ca.env
grep -qx "corporate-ca" /tmp/dotfiles-work-ca-home/.config/dotfiles/selected-tools

echo "==> no-doctor"
rm -rf /tmp/dotfiles-no-doctor-home
mkdir -p /tmp/dotfiles-no-doctor-home
HOME=/tmp/dotfiles-no-doctor-home ./setup install \
  --no-doctor \
  --non-interactive \
  --profile personal \
  --git-name "No Doctor" \
  --git-email nodoctor@example.com \
  --tools minimal \
  --docker none \
  --default-shell zsh 2>&1 | tee /tmp/setup-no-doctor.txt

grep -q "^Complete$" /tmp/setup-no-doctor.txt
! grep -q "^Doctor$" /tmp/setup-no-doctor.txt
grep -q "DOTFILES_TEST_MODE: skipped login shell change" /tmp/setup-no-doctor.txt

echo "==> verify/doctor smoke"
./setup verify || true
./setup doctor >/tmp/setup-doctor.txt
grep -q "^Doctor$" /tmp/setup-doctor.txt
! grep -q "Dotfiles doctor" /tmp/setup-doctor.txt
grep -q "Available follow-ups" /tmp/setup-doctor.txt

docker_warns="$(grep -c "Docker missing or the selected Docker strategy is not ready" /tmp/setup-doctor.txt || true)"
test "$docker_warns" -le 1

echo "Docker test pipeline passed"
