#!/usr/bin/env bash
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$DOTFILES_ROOT/lib/common.sh"
source "$DOTFILES_ROOT/install/verify.sh"
action_doctor() { action_verify; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then action_doctor; fi
