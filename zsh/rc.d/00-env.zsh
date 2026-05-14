export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export WORKDIR="${WORKDIR:-$HOME/work}"
export EDITOR="${EDITOR:-code}"
export VISUAL="${VISUAL:-code}"
export PAGER="${PAGER:-less -FRX}"

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

unset _dotfiles_profile
