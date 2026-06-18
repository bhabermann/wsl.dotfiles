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
PROFILE_FILE="$DOTFILES_CFG_DIR/profile"

if [[ -f "$PROFILE_FILE" ]]; then
  _dotfiles_profile="$(tr -d '[:space:]' < "$PROFILE_FILE")"
  if [[ -n "$_dotfiles_profile" && -f "$DOTFILES/profiles/${_dotfiles_profile}.env" ]]; then
    source "$DOTFILES/profiles/${_dotfiles_profile}.env"
  fi
fi

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

command -v fdfind >/dev/null 2>&1 && alias fd="fdfind"
command -v batcat >/dev/null 2>&1 && alias bat="batcat"
alias ll="ls -la"
alias gst="git status"
alias gco="git checkout"
alias gcb="git checkout -b"
alias glg="git log --oneline --graph --decorate --all"
command -v eza >/dev/null 2>&1 && alias ls="eza"
command -v bat >/dev/null 2>&1 && alias cat="bat"
command -v rg >/dev/null 2>&1 && alias grep="rg"

unset _dotfiles_profile _dotfiles_root_file
