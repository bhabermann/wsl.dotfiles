#!/usr/bin/env bash

action_uninstall() {
  cat <<'EOF'
Uninstall is intentionally conservative.

Manual cleanup targets:
  Marker-managed blocks in ~/.bashrc and ~/.zshrc
  ~/.config/dotfiles/shell/
  ~/.gitconfig
  ~/.config/mise/config.toml
  ~/.config/mise/default-tools.toml
  ~/.config/starship.toml
  ~/.local/bin/wslview

The PowerShell profiles may contain a marker-managed "dotfiles docker-wsl"
function block.

Local machine files are not removed automatically:
  ~/.config/dotfiles/
  ~/.config/git/identity.gitconfig
  ~/.ssh/config
EOF
}
