#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "==> bash syntax"
bash -n setup lib/common.sh lib/tools.sh install/*.sh scripts/*.sh scripts/update-corporate-ca

echo "==> help"
./setup help >/tmp/setup-help.txt
grep -q "Usage: ./setup" /tmp/setup-help.txt
grep -q -- "--reconfigure" /tmp/setup-help.txt

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
printf "%s\n" runtime shell history > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=wsl-engine resolve_tool_selection --' > "$actual"
printf "%s\n" runtime shell modern-cli docker-wsl-engine > "$expected"
diff -u "$expected" "$actual"

saved_home="$(mktemp -d)"
mkdir -p "$saved_home/.config/dotfiles"
printf "%s\n" base shell history docker-wsl-engine > "$saved_home/.config/dotfiles/selected-tools"
HOME="$saved_home" bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 resolve_tool_selection --' > "$actual"
printf "%s\n" runtime shell history docker-wsl-engine > "$expected"
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
! grep -qx "corporate-ca" "$actual"

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
ALLOWLIST_REGEX="Example"
TEST_URLS=()
EOF
./scripts/update-corporate-ca --config "$ca_config" --print-config >/tmp/update-corporate-ca-config.txt
grep -q "127.0.0.1" /tmp/update-corporate-ca-config.txt
./scripts/update-corporate-ca --config "$ca_config" --dry-run >/tmp/update-corporate-ca-dry-run.txt 2>&1
grep -q "Dry-run completed" /tmp/update-corporate-ca-dry-run.txt
HOME=/tmp/dotfiles-missing-ca-home ./scripts/update-corporate-ca --dry-run >/tmp/update-corporate-ca-missing.txt 2>&1 && exit 1
grep -q "Config file not found" /tmp/update-corporate-ca-missing.txt

echo "==> non-interactive test-mode install"
export HOME=/tmp/dotfiles-home
export DOTFILES_TEST_MODE=1
rm -rf "$HOME"
mkdir -p "$HOME"

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
grep -q "Installing dependency setup: Ubuntu base packages" /tmp/setup-install-first.txt
grep -q "DOTFILES_TEST_MODE: skipped dependency package installation" /tmp/setup-install-first.txt
dependency_line="$(grep -n "Installing dependency setup: Ubuntu base packages" /tmp/setup-install-first.txt | cut -d: -f1 | head -n1)"
shell_line="$(grep -n "Installing shell tools" /tmp/setup-install-first.txt | cut -d: -f1 | head -n1)"
test "$dependency_line" -lt "$shell_line"
grep -q "Default shell:.*zsh" /tmp/setup-install-first.txt
grep -q "DOTFILES_TEST_MODE: skipped login shell change" /tmp/setup-install-first.txt

test "$(cat "$HOME/.config/dotfiles/profile")" = "personal"
test "$(cat "$HOME/.config/dotfiles/root")" = "/workspace"
test -L "$HOME/.zshrc"
test -L "$HOME/.gitconfig"
test -L "$HOME/.config/mise/config.toml"
test -L "$HOME/.config/mise/default-tools.toml"
test -L "$HOME/.config/starship.toml"
test -f "$HOME/.config/git/identity.gitconfig"
test -f "$HOME/.ssh/config"
test -f "$HOME/.config/dotfiles/selected-tools"
test "$(cat "$HOME/.config/dotfiles/default-shell")" = "zsh"
! grep -qx "base" "$HOME/.config/dotfiles/selected-tools"
! grep -qx "corporate-ca" "$HOME/.config/dotfiles/selected-tools"
grep -q "Test User" "$HOME/.config/git/identity.gitconfig"
grep -q "test@example.com" "$HOME/.config/git/identity.gitconfig"
zsh -ic 'test "$DOTFILES" = "/workspace"'
zsh -ic 'alias ll' | grep -q 'ls -la'
zsh -ic 'whence -w path_prepend' | grep -q 'function'
! zsh -ic 'true' 2>&1 | grep -q 'no matches found'

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
grep -q "Git identity:.*configured at" /tmp/setup-install-second.txt
grep -q "Default shell:.*unchanged" /tmp/setup-install-second.txt

./setup install \
  --non-interactive \
  --no-doctor 2>&1 | tee /tmp/setup-install-detected.txt

grep -q "Profile:.*personal (saved state)" /tmp/setup-install-detected.txt
grep -q "Git identity:.*configured at" /tmp/setup-install-detected.txt
grep -q "Tool selection:.*saved state" /tmp/setup-install-detected.txt
grep -q "Docker:.*None (saved state)" /tmp/setup-install-detected.txt
grep -q "Default shell:.*unchanged" /tmp/setup-install-detected.txt

after_identity="$(sha256sum "$HOME/.config/git/identity.gitconfig")"
after_ssh="$(sha256sum "$HOME/.ssh/config")"
test "$before_identity" = "$after_identity"
test "$before_ssh" = "$after_ssh"
grep -q "Test User" "$HOME/.config/git/identity.gitconfig"
! grep -q "Changed User" "$HOME/.config/git/identity.gitconfig"

echo "==> reconfigure keeps saved values"
printf "\n\n\n\n\n\n\ny\n" | ./setup install --reconfigure --no-doctor 2>&1 | tee /tmp/setup-reconfigure-keep.txt
grep -q "Profile:.*personal (reconfigure prompt)" /tmp/setup-reconfigure-keep.txt
grep -q "Tool selection:.*reconfigure prompts" /tmp/setup-reconfigure-keep.txt
grep -q "Docker:.*None (reconfigure prompts)" /tmp/setup-reconfigure-keep.txt
grep -q "Default shell:.*unchanged (reconfigure prompt)" /tmp/setup-reconfigure-keep.txt
test "$(cat "$HOME/.config/dotfiles/default-shell")" = "unchanged"
printf "%s\n" shell > "$expected"
diff -u "$expected" "$HOME/.config/dotfiles/selected-tools"

echo "==> reconfigure changes saved values"
printf "\n\n\n\n\n1\n1\ny\n" | ./setup install --reconfigure --no-doctor 2>&1 | tee /tmp/setup-reconfigure-change.txt
grep -q "Docker:.*Docker Desktop (reconfigure prompts)" /tmp/setup-reconfigure-change.txt
grep -q "Default shell:.*zsh (reconfigure prompt)" /tmp/setup-reconfigure-change.txt
grep -qx "docker-desktop" "$HOME/.config/dotfiles/selected-tools"
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

echo "==> corporate CA selected install"
rm -rf /tmp/dotfiles-work-ca-home
mkdir -p /tmp/dotfiles-work-ca-home
HOME=/tmp/dotfiles-work-ca-home ./setup install \
  --non-interactive \
  --profile work \
  --git-name "Work CA" \
  --git-email workca@example.com \
  --tools minimal \
  --with corporate-ca \
  --docker none \
  --default-shell unchanged 2>&1 | tee /tmp/setup-work-ca.txt

grep -q "Corporate CA" /tmp/setup-work-ca.txt
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

docker_warns="$(grep -c "Docker missing or Docker Desktop WSL integration disabled" /tmp/setup-doctor.txt || true)"
test "$docker_warns" -le 1

echo "Docker test pipeline passed"
