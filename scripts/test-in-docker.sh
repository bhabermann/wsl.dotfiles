#!/usr/bin/env bash
set -euo pipefail

cd /workspace

echo "==> bash syntax"
bash -n setup lib/common.sh lib/tools.sh install/*.sh scripts/*.sh

echo "==> help"
./setup help >/tmp/setup-help.txt
grep -q "Usage: ./setup" /tmp/setup-help.txt

echo "==> tool selection parser"
actual="$(mktemp)"
expected="$(mktemp)"
bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=desktop resolve_tool_selection history -- modern-cli' > "$actual"
printf "%s\n" base runtime shell history docker-desktop > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=all DOCKER_STRATEGY=none resolve_tool_selection -- history' > "$actual"
printf "%s\n" base runtime shell modern-cli > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=minimal DOCKER_STRATEGY=none resolve_tool_selection history --' > "$actual"
printf "%s\n" base runtime shell history > "$expected"
diff -u "$expected" "$actual"

bash -lc 'source /workspace/lib/common.sh; source /workspace/lib/tools.sh; NON_INTERACTIVE=1 TOOLS_PRESET=recommended DOCKER_STRATEGY=wsl-engine resolve_tool_selection --' > "$actual"
printf "%s\n" base runtime shell modern-cli docker-wsl-engine > "$expected"
diff -u "$expected" "$actual"

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
  --tools minimal \
  --docker none 2>&1 | tee /tmp/setup-install-detected.txt

grep -q "Profile:.*personal (from /tmp/dotfiles-home/.config/dotfiles/profile)" /tmp/setup-install-detected.txt
grep -q "Git identity:.*configured at" /tmp/setup-install-detected.txt
grep -q "Default shell:.*unchanged" /tmp/setup-install-detected.txt

after_identity="$(sha256sum "$HOME/.config/git/identity.gitconfig")"
after_ssh="$(sha256sum "$HOME/.ssh/config")"
test "$before_identity" = "$after_identity"
test "$before_ssh" = "$after_ssh"
grep -q "Test User" "$HOME/.config/git/identity.gitconfig"
! grep -q "Changed User" "$HOME/.config/git/identity.gitconfig"

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
grep -q "Dry run:.*no changes were made" /tmp/setup-dry-run.txt
! grep -q "^Installation$" /tmp/setup-dry-run.txt
! grep -q "^Linking$" /tmp/setup-dry-run.txt
test ! -e /tmp/dotfiles-dry-home/.zshrc
test ! -e /tmp/dotfiles-dry-home/.gitconfig
test ! -e /tmp/dotfiles-dry-home/.config/dotfiles/profile
test ! -e /tmp/dotfiles-dry-home/.config/dotfiles/root
test ! -e /tmp/dotfiles-dry-home/.config/git/identity.gitconfig

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
