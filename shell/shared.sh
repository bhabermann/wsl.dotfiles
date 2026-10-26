# Shared interactive-shell configuration for Bash and Zsh.

if [[ -z "${DOTFILES:-}" ]]; then
  _dotfiles_root_file="$HOME/.config/dotfiles/root"
  if [[ -r "$_dotfiles_root_file" ]]; then
    IFS= read -r DOTFILES < "$_dotfiles_root_file"
  fi
  [[ -n "${DOTFILES:-}" && -d "$DOTFILES" ]] || DOTFILES="$HOME/.dotfiles"
  export DOTFILES
fi

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export EDITOR="${EDITOR:-code}"
export VISUAL="${VISUAL:-code}"
export PAGER="${PAGER:-less -FRX}"
export BROWSER="${BROWSER:-wslview}"

DOTFILES_CFG_DIR="$HOME/.config/dotfiles"
[[ -f "$DOTFILES_CFG_DIR/local.env" ]] && source "$DOTFILES_CFG_DIR/local.env"
[[ -f "$DOTFILES_CFG_DIR/secrets.env" ]] && source "$DOTFILES_CFG_DIR/secrets.env"

path_prepend() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

path_append() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.local/share/mise/shims"
path_append "/usr/local/bin"
export PATH

[[ -x /usr/bin/fdfind ]] && alias fd="fdfind"
[[ -x /usr/bin/batcat ]] && alias bat="batcat"
alias ll="ls -la"
alias gst="git status"
alias gco="git checkout"
alias gcb="git checkout -b"
alias glg="git log --oneline --graph --decorate --all"
[[ -x /usr/bin/eza ]] && alias ls="eza"
[[ -x /usr/bin/bat || -x /usr/bin/batcat ]] && alias cat="bat"
[[ -x /usr/bin/rg ]] && alias grep="rg"

unset _dotfiles_root_file
