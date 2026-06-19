#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_ROOT/lib/common.sh"

ONLY_MISE=0
[[ "${1:-}" == "--only-mise" ]] && ONLY_MISE=1

mkdir -p "$DOTFILES_CONFIG_DIR"
printf "%s\n" "$DOTFILES_ROOT" > "$DOTFILES_CONFIG_DIR/root"

mkdir -p "$HOME/.config/mise"
link_file "$DOTFILES_ROOT/mise/config.toml" "$HOME/.config/mise/config.toml"
link_file "$DOTFILES_ROOT/mise/default-tools.toml" "$HOME/.config/mise/default-tools.toml"

[[ "$ONLY_MISE" == "1" ]] && exit 0

mkdir -p "$DOTFILES_CONFIG_DIR/shell"
link_file "$DOTFILES_ROOT/shell/shared.sh" "$DOTFILES_CONFIG_DIR/shell/shared.sh"
link_file "$DOTFILES_ROOT/shell/bashrc" "$DOTFILES_CONFIG_DIR/shell/bashrc"
link_file "$DOTFILES_ROOT/shell/zshrc" "$DOTFILES_CONFIG_DIR/shell/zshrc"
ensure_managed_source_block "$HOME/.bashrc" bashrc
ensure_managed_source_block "$HOME/.zshrc" zshrc "$DOTFILES_ROOT/zsh/zshrc"
link_file "$DOTFILES_ROOT/git/gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_ROOT/starship/starship.toml" "$HOME/.config/starship.toml"
mkdir -p "$HOME/.local/bin"
link_file "$DOTFILES_ROOT/scripts/wslview" "$HOME/.local/bin/wslview"

copy_template_if_missing "$DOTFILES_ROOT/templates/git/identity.gitconfig.template" "$HOME/.config/git/identity.gitconfig"
if [[ "$ONLY_MISE" == "0" && "${GIT_IDENTITY_WRITE:-0}" == "1" && -n "${GIT_NAME:-}" && -n "${GIT_EMAIL:-}" ]]; then
  current_name="$(git config --file "$HOME/.config/git/identity.gitconfig" --get user.name 2>/dev/null || true)"
  current_email="$(git config --file "$HOME/.config/git/identity.gitconfig" --get user.email 2>/dev/null || true)"
  if [[ "$current_name" != "$GIT_NAME" || "$current_email" != "$GIT_EMAIL" ]]; then
    git config --file "$HOME/.config/git/identity.gitconfig" user.name "$GIT_NAME"
    git config --file "$HOME/.config/git/identity.gitconfig" user.email "$GIT_EMAIL"
    ok "Updated git identity in $HOME/.config/git/identity.gitconfig"
  fi
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
copy_template_if_missing "$DOTFILES_ROOT/templates/ssh/config.template" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config" || true

copy_template_if_missing "$DOTFILES_ROOT/templates/dotfiles/local.env.template" "$DOTFILES_CONFIG_DIR/local.env"
copy_template_if_missing "$DOTFILES_ROOT/templates/dotfiles/profile.template" "$DOTFILES_CONFIG_DIR/profile"
