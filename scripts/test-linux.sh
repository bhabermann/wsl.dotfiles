#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
cd "$test_root"
for file in "$root/setup" "$root"/{lib,install,shell,windows,scripts}/*.sh "$root/scripts/docker-wsl"; do
  bash -n "$file"
done
"$root/setup" help >/dev/null
export HOME="$test_root/home" DOTFILES_TEST_MODE=1
mkdir -p "$HOME"
arguments=(install --non-interactive --git-name 'Fixture User' --git-email fixture@example.invalid --tools minimal --docker none)
"$root/setup" "${arguments[@]}" --dry-run > "$test_root/dry"
test ! -e "$HOME/.config"
if "$root/setup" "${arguments[@]}" --with nonexistent >/dev/null 2>&1; then echo 'Unknown tool accepted' >&2; exit 1; fi
if "$root/setup" "${arguments[@]}" --profile personal >/dev/null 2>&1; then echo 'Retired profile accepted' >&2; exit 1; fi
printf '# user bash content\n' > "$HOME/.bashrc"
printf '# user zsh content\n' > "$HOME/.zshrc"
"$root/setup" "${arguments[@]}" > "$test_root/first"
test ! -e "$HOME/.config/dotfiles/profile"
test ! -s "$HOME/.config/dotfiles/selected-tools"
! grep -q '^\[tools\]' "$HOME/.config/mise/config.toml"
test "$(git config --global --includes user.email)" = fixture@example.invalid
grep -q '# user zsh content' "$HOME/.zshrc"
test ! -L "$HOME/.zshrc"
"$root/setup" install --non-interactive > "$test_root/second"
test "$(grep -c '# >>> dotfiles managed >>>' "$HOME/.zshrc")" = 1
test "$(cat "$HOME/.config/dotfiles/docker")" = none
test "$(git config --global --includes user.name)" = 'Fixture User'
"$root/setup" "${arguments[@]}" --with python --with fd > "$test_root/selection"
grep -qx python "$HOME/.config/dotfiles/selected-tools"
grep -qx fd "$HOME/.config/dotfiles/selected-tools"
"$root/setup" "${arguments[@]}" --tools recommended > "$test_root/recommended"
! grep -Eq '^(node|dotnet|python|go|uv|java)$' "$HOME/.config/dotfiles/selected-tools"
(
  source "$root/lib/tools.sh"
  source "$root/install/install.sh"
  DOTFILES_ROOT="$root"
  install_mise() { :; }
  sudo() { :; }
  mise() { printf '%s\n' "$*" >> "$test_root/runtime-requests"; }
  install_tool python
  install_tool java
  install_tool node
)
grep -qx 'use --global python' "$test_root/runtime-requests"
grep -qx 'where java' "$test_root/runtime-requests"
grep -qx 'use --global node@24.17.0' "$test_root/runtime-requests"
set +e
(
  set -e
  export HOME="$test_root/failing-home"
  mkdir -p "$HOME"
  source "$root/lib/common.sh"
  source "$root/lib/tools.sh"
  source "$root/install/install.sh"
  DOTFILES_ROOT="$root" DOTFILES_TEST_MODE=0 NON_INTERACTIVE=1
  GIT_NAME='Saved Before Failure' GIT_EMAIL=saved@example.invalid
  TOOLS_PRESET=minimal DRY_RUN=0 DOCKER_STRATEGY=none DEFAULT_SHELL=zsh
  WITH_ITEMS=() WITHOUT_ITEMS=()
  is_debian_13() { return 0; }
  require_sudo() { return 42; }
  action_install
) > "$test_root/failing-install" 2>&1
status=$?
set -e
test "$status" = 42
test "$(git config --file "$test_root/failing-home/.config/git/identity.gitconfig" user.name)" = 'Saved Before Failure'
bash --noprofile --rcfile "$HOME/.bashrc" -ic 'test -n "$DOTFILES"' 2>/dev/null
mkdir -p "$test_root/bin"
cat > "$test_root/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$CAPTURE"
exit "${MOCK_EXIT:-0}"
EOF
cat > "$test_root/bin/wslpath" <<'EOF'
#!/usr/bin/env bash
path="${2//\\//}"
printf '/mnt/%s%s' "${path:0:1}" "${path:2}"
EOF
chmod +x "$test_root/bin/"*
export PATH="$test_root/bin:$PATH" CAPTURE="$test_root/capture" DOCKER_WSL_SKIP_WAIT=1
"$root/scripts/docker-wsl" run --rm -e 'KEEP=C:\unchanged' -v 'C:\project dir:/work:ro' --mount 'type=bind,src=C:\other dir,dst=/data' alpine echo 'a & b'
mapfile -d '' -t actual < "$CAPTURE"
test "${actual[3]}" = 'KEEP=C:\unchanged'
test "${actual[5]}" = '/mnt/C/project dir:/work:ro'
test "${actual[7]}" = 'type=bind,src=/mnt/C/other dir,dst=/data'
test "${actual[10]}" = 'a & b'
"$root/scripts/docker-wsl" compose -f 'C:\project dir\compose.yaml' --project-directory 'C:\project dir' config
mapfile -d '' -t actual < "$CAPTURE"
test "${actual[2]}" = '/mnt/C/project dir/compose.yaml'
test "${actual[4]}" = '/mnt/C/project dir'
"$root/scripts/docker-wsl" build -f 'C:\project dir\Dockerfile' 'C:\project dir'
mapfile -d '' -t actual < "$CAPTURE"
test "${actual[2]}" = '/mnt/C/project dir/Dockerfile'
test "${actual[3]}" = '/mnt/C/project dir'
export MOCK_EXIT=37
status=0
"$root/scripts/docker-wsl" version || status=$?
test "$status" = 37
echo 'PASS: Linux installer, identity, dry-run, rerun, selection, and Docker argument fixtures'
