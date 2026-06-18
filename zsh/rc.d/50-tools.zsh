if [[ -x /usr/bin/mise ]]; then
  eval "$(/usr/bin/mise activate zsh)" 2>/dev/null || true
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)" 2>/dev/null || true
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)" 2>/dev/null || true
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
