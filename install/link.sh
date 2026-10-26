#!/usr/bin/env bash
set -euo pipefail
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_ROOT/lib/common.sh"
mkdir -p "$DOTFILES_CONFIG_DIR/shell" "$HOME/.config/git" "$HOME/.config/mise" "$HOME/.local/bin"
printf '%s\n' "$DOTFILES_ROOT" > "$DOTFILES_CONFIG_DIR/root"
for file in shared.sh bashrc zshrc; do
  link_file "$DOTFILES_ROOT/shell/$file" "$DOTFILES_CONFIG_DIR/shell/$file"
done
ensure_managed_source_block "$HOME/.bashrc" bashrc
ensure_managed_source_block "$HOME/.zshrc" zshrc "$DOTFILES_ROOT/zsh/zshrc"
link_file "$DOTFILES_ROOT/git/gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_ROOT/starship/starship.toml" "$HOME/.config/starship.toml"
link_file "$DOTFILES_ROOT/scripts/wslview" "$HOME/.local/bin/wslview"
copy_template_if_missing "$DOTFILES_ROOT/mise/config.toml" "$HOME/.config/mise/config.toml"
copy_template_if_missing "$DOTFILES_ROOT/templates/git/identity.gitconfig.template" "$HOME/.config/git/identity.gitconfig"
if [[ "${GIT_IDENTITY_WRITE:-0}" == 1 ]]; then
  git -C "$HOME" config --file "$HOME/.config/git/identity.gitconfig" user.name "$GIT_NAME"
  git -C "$HOME" config --file "$HOME/.config/git/identity.gitconfig" user.email "$GIT_EMAIL"
fi
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
copy_template_if_missing "$DOTFILES_ROOT/templates/ssh/config.template" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
copy_template_if_missing "$DOTFILES_ROOT/templates/dotfiles/local.env.template" "$DOTFILES_CONFIG_DIR/local.env"
