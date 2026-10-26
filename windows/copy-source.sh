#!/usr/bin/env bash
set -euo pipefail
source_directory="$1"
destination="$HOME/.dotfiles"
mkdir -p "$destination"
tar -C "$source_directory" --exclude=.git --exclude='*.bak.*' -cf - . |
  tar -C "$destination" -xf -
find "$destination" -type f \( -name '*.sh' -o -name setup -o -name wslview -o -name docker-wsl \) -exec chmod +x {} +
