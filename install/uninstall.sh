#!/usr/bin/env bash

action_uninstall() {
  cat <<'EOF'
Uninstall is intentionally conservative.

Manual cleanup targets:
  ~/.zshrc
  ~/.gitconfig
  ~/.config/mise/config.toml
  ~/.config/mise/default-tools.toml
  ~/.config/starship.toml

Local machine files are not removed automatically:
  ~/.config/dotfiles/
  ~/.config/git/identity.gitconfig
  ~/.ssh/config
EOF
}
