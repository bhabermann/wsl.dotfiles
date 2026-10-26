#!/usr/bin/env bash
action_uninstall() {
  cat <<'EOF'
Conservative cleanup guidance (no files are deleted):
- Remove the dotfiles managed blocks from ~/.bashrc and ~/.zshrc.
- Remove managed links under ~/.config/dotfiles/shell and ~/.local/bin.
- Restore ~/.gitconfig and ~/.config/starship.toml from ~/.dotfiles-backup if needed.
- Windows: remove the dotfiles managed profile block, its Terminal fragment,
  and the managed bin directory from your user PATH. Restore the saved Terminal
  settings/default distro if desired.
Identity, SSH files, runtime installations, and Docker data remain yours.
Unregistering a WSL distro deletes its entire disk; export data first.
EOF
}
